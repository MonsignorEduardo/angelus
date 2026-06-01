defmodule Angelus.Motor.Server do
  @moduledoc "GenServer that owns the native `angelus_motor` Port and serializes SPICE calls."

  use GenServer

  alias Angelus.Motor.KernelSet
  alias Angelus.Motor.WorkerProtocol

  @worker_bin "angelus_worker"

  # ── GenServer ────────────────────────────────────────────────────────────

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(_opts) do
    base = %{
      port: nil,
      next_id: 1,
      pending: %{},
      loaded?: false,
      metadata: nil
    }

    case open_port() do
      {:ok, port} ->
        state = %{base | port: port}
        # Clear any residual CSPICE state at startup
        {id, state} = next_id(state)
        send_to_port(port, WorkerProtocol.encode_clear_kernels(id))
        {:ok, state}

      {:error, {:worker_not_found, _bin}} ->
        # Binary not compiled yet — start without a port.
        # Calls that require CSPICE will return {:error, :worker_not_available}.
        # Structural validation (whitelist, missing files, etc.) still works.
        {:ok, base}
    end
  end

  # ── Call handlers ────────────────────────────────────────────────────────

  @impl true
  # load_kernels: structural validation runs before port check so whitelist
  # errors are returned even when the worker binary is absent.
  @spec handle_call(term(), GenServer.from(), map()) ::
          {:reply, term(), map()} | {:noreply, map()}
  def handle_call({:load_kernels, paths, opts}, from, state) do
    replace? = Keyword.get(opts, :replace, false)

    case KernelSet.validate(paths) do
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      {:ok, _metadata} when state.port == nil ->
        {:reply, {:error, :worker_not_available}, state}

      {:ok, metadata} ->
        if state.loaded? and not replace? do
          {:reply, {:error, :kernels_already_loaded}, state}
        else
          do_load_kernels(paths, metadata, replace?, from, state)
        end
    end
  end

  # ephemeride / lunar_node: return kernels_not_loaded when no kernels (covers nil port too)
  def handle_call({:ephemeride, _target, _utc, _opts}, _from, %{loaded?: false} = state),
    do: {:reply, {:error, :kernels_not_loaded}, state}

  def handle_call({:ephemeride, target, utc, opts}, from, state) do
    iso8601 = DateTime.to_iso8601(utc)
    units = Keyword.get(opts, :units, "deg")
    {id, new_state} = next_id(state)

    send_to_port(state.port, WorkerProtocol.encode_ephemeride(id, target, iso8601, units))

    meta = %{
      observer: Keyword.get(opts, :observer, :earth),
      abcorr: "LT+S",
      frame_base: "ECLIPJ2000",
      kernel_metadata: state.metadata
    }

    pending = Map.put(new_state.pending, id, {:ephemeride, from, meta})
    {:noreply, %{new_state | pending: pending}}
  end

  def handle_call({:lunar_node, _calculation, _utc, _opts}, _from, %{loaded?: false} = state),
    do: {:reply, {:error, :kernels_not_loaded}, state}

  def handle_call({:lunar_node, calculation, utc, opts}, from, state) do
    iso8601 = DateTime.to_iso8601(utc)
    units = Keyword.get(opts, :units, "deg")
    {id, new_state} = next_id(state)

    send_to_port(state.port, WorkerProtocol.encode_lunar_node(id, calculation, iso8601, units))

    pending = Map.put(new_state.pending, id, {:lunar_node, from})
    {:noreply, %{new_state | pending: pending}}
  end

  def handle_call(:metadata, _from, state), do: {:reply, {:ok, state.metadata}, state}

  # Catch-all for calls when port is unavailable (should rarely be reached)
  def handle_call(_message, _from, state),
    do: {:reply, {:error, :worker_not_available}, state}

  # ── Port messages ────────────────────────────────────────────────────────

  @impl true
  @spec handle_info(term(), map()) :: {:noreply, map()}
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    case WorkerProtocol.decode(data) do
      {:error, :decode_error, _raw} ->
        # Malformed response — log and continue; don't crash
        {:noreply, state}

      {:ok, id, result} ->
        handle_worker_reply(id, {:ok, result}, state)

      {:error, id, reason} ->
        handle_worker_reply(id, {:error, reason}, state)
    end
  end

  def handle_info({port, {:exit_status, _status}}, %{port: port} = state) do
    # Worker crashed; reply worker_crashed to all pending callers
    Enum.each(state.pending, fn {_id, waiter} ->
      reply_to_waiter(waiter, {:error, :worker_crashed})
    end)

    case open_port() do
      {:ok, new_port} ->
        {:noreply, %{state | port: new_port, pending: %{}, loaded?: false, metadata: nil}}

      {:error, _reason} ->
        {:noreply, %{state | port: nil, pending: %{}, loaded?: false, metadata: nil}}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ── Public API ───────────────────────────────────────────────────────────

  @doc "Starts the named Motor server process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Loads validated kernel paths into the native worker."
  @spec load_kernels([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def load_kernels(paths, opts), do: call({:load_kernels, paths, opts})

  @doc "Combined UTC -> ET -> state round-trip via the native worker."
  @spec ephemeride(String.t(), DateTime.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def ephemeride(target, utc, opts), do: call({:ephemeride, target, utc, opts})

  @doc """
  Computes the ecliptic longitude of the Moon's ascending node using ERFA.

  Accepts a `%DateTime{}` and optional opts (e.g., `units: "rad").
  """
  @spec lunar_node(:mean_lunar_node | :true_lunar_node, DateTime.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def lunar_node(calculation, utc, opts \\ []), do: call({:lunar_node, calculation, utc, opts})

  @doc "Returns metadata for the currently loaded kernel set, if any."
  @spec metadata() :: {:ok, map() | nil}
  def metadata, do: call(:metadata)

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp next_id(%{next_id: id} = state) do
    {id, %{state | next_id: id + 1}}
  end

  defp open_port do
    bin = worker_bin_path()

    if File.exists?(bin) do
      port =
        Port.open({:spawn_executable, bin}, [
          :binary,
          :exit_status,
          {:packet, 4},
          :use_stdio
        ])

      {:ok, port}
    else
      {:error, {:worker_not_found, bin}}
    end
  end

  defp worker_bin_path do
    case :code.priv_dir(:angelus) do
      {:error, _} -> Path.join(["priv", @worker_bin])
      priv_dir -> Path.join(List.to_string(priv_dir), @worker_bin)
    end
  end

  defp send_to_port(port, json) when is_binary(json) do
    Port.command(port, json)
  end

  defp do_load_kernels(paths, metadata, replace?, from, state) do
    if replace? do
      {clear_id, state1} = next_id(state)
      send_to_port(state1.port, WorkerProtocol.encode_clear_kernels(clear_id))

      {load_id, state2} = next_id(state1)
      send_to_port(state2.port, WorkerProtocol.encode_load_kernels(load_id, paths))

      pending =
        state2.pending
        |> Map.put(clear_id, :clear_ack)
        |> Map.put(load_id, {:load_kernels, from, metadata})

      {:noreply, %{state2 | pending: pending, loaded?: false, metadata: nil}}
    else
      {load_id, state1} = next_id(state)
      send_to_port(state1.port, WorkerProtocol.encode_load_kernels(load_id, paths))

      pending = Map.put(state1.pending, load_id, {:load_kernels, from, metadata})
      {:noreply, %{state1 | pending: pending}}
    end
  end

  defp handle_worker_reply(id, result, state) do
    case Map.pop(state.pending, id) do
      {nil, _} ->
        # Unexpected id (e.g. startup clear_kernels ack) — ignore
        {:noreply, state}

      {:clear_ack, remaining} ->
        {:noreply, %{state | pending: remaining}}

      {{:load_kernels, from, metadata}, remaining} ->
        case result do
          {:ok, _} ->
            GenServer.reply(from, {:ok, metadata})
            {:noreply, %{state | pending: remaining, loaded?: true, metadata: metadata}}

          {:error, reason} ->
            GenServer.reply(from, {:error, {:kernel_load_failed, reason}})
            {:noreply, %{state | pending: remaining, loaded?: false, metadata: nil}}
        end

      {{:ephemeride, from, meta}, remaining} ->
        reply = handle_state_result(result, meta)
        GenServer.reply(from, reply)
        {:noreply, %{state | pending: remaining}}

      {{:lunar_node, from}, remaining} ->
        reply = handle_lunar_node_result(result)
        GenServer.reply(from, reply)
        {:noreply, %{state | pending: remaining}}
    end
  end

  defp handle_state_result({:ok, raw}, meta) do
    case WorkerProtocol.coerce_state(raw) do
      {:ok, coerced} -> {:ok, Map.merge(coerced, state_metadata(meta))}
      {:error, _} -> {:error, :invalid_state_result}
    end
  end

  defp handle_state_result({:error, _} = err, _meta), do: err

  defp handle_lunar_node_result({:ok, raw}) do
    case WorkerProtocol.coerce_state(raw) do
      {:ok, coerced} -> {:ok, coerced}
      {:error, _} -> {:error, :invalid_state_result}
    end
  end

  defp handle_lunar_node_result({:error, _} = err), do: err

  defp state_metadata(meta) do
    %{
      observer: meta.observer,
      abcorr: meta.abcorr,
      frame_base: meta.frame_base,
      kernel_metadata: meta.kernel_metadata
    }
  end

  defp reply_to_waiter({:load_kernels, from, _meta}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter({:lunar_node, from}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter({:ephemeride, from, _meta}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter(:clear_ack, _reply), do: :ok
  defp reply_to_waiter(nil, _reply), do: :ok

  defp call(message) do
    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, message, 30_000)
    else
      {:error, :motor_server_not_started}
    end
  end
end
