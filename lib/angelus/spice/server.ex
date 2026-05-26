defmodule Angelus.Spice.Server do
  @moduledoc false

  use GenServer

  alias Angelus.Spice.KernelSet
  alias Angelus.Spice.WorkerProtocol

  @worker_bin "spice_worker"

  # ── Public API ───────────────────────────────────────────────────────────

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def load_kernels(paths, opts), do: call({:load_kernels, paths, opts})
  def utc_to_et(datetime), do: call({:utc_to_et, datetime})
  def state(body, et, opts), do: call({:state, body, et, opts})
  def metadata, do: call(:metadata)

  # ── GenServer ────────────────────────────────────────────────────────────

  @impl true
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

  # utc_to_et / state: return kernels_not_loaded when no kernels (covers nil port too)
  def handle_call({:utc_to_et, _datetime}, _from, %{loaded?: false} = state),
    do: {:reply, {:error, :kernels_not_loaded}, state}

  def handle_call({:utc_to_et, datetime}, from, state) do
    iso8601 = DateTime.to_iso8601(datetime)
    {id, new_state} = next_id(state)

    send_to_port(state.port, WorkerProtocol.encode_utc_to_et(id, iso8601))

    pending = Map.put(new_state.pending, id, {:utc_to_et, from})
    {:noreply, %{new_state | pending: pending}}
  end

  def handle_call({:state, _body, _et, _opts}, _from, %{loaded?: false} = state),
    do: {:reply, {:error, :kernels_not_loaded}, state}

  def handle_call({:state, body, et, opts}, from, state) do
    with {:ok, target} <- Angelus.Spice.BodyTargets.fetch(body),
         :ok <- validate_native_target(body, target) do
      {id, new_state} = next_id(state)

      send_to_port(
        state.port,
        WorkerProtocol.encode_state(id, target.spice_target, et)
      )

      meta = %{
        body: body,
        spice_target: target.spice_target,
        spice_id: target.spice_id,
        target_kind: target.target_kind,
        observer: Keyword.get(opts, :observer, :earth),
        abcorr: "LT+S",
        frame_base: "ECLIPJ2000",
        kernel_metadata: state.metadata
      }

      pending = Map.put(new_state.pending, id, {:state, from, meta})
      {:noreply, %{new_state | pending: pending}}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:metadata, _from, state), do: {:reply, {:ok, state.metadata}, state}

  # Catch-all for calls when port is unavailable (should rarely be reached)
  def handle_call(_message, _from, state),
    do: {:reply, {:error, :worker_not_available}, state}

  # ── Port messages ────────────────────────────────────────────────────────

  @impl true
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

  defp validate_native_target(_body, %{spice_target: t}) when is_binary(t), do: :ok

  defp validate_native_target(body, _target),
    do: {:error, {:unsupported_native_body, body}}

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

      {{:utc_to_et, from}, remaining} ->
        GenServer.reply(from, result)
        {:noreply, %{state | pending: remaining}}

      {{:state, from, meta}, remaining} ->
        reply =
          case result do
            {:ok, raw} ->
              case WorkerProtocol.coerce_state(raw) do
                {:ok, coerced} ->
                  {:ok,
                   Map.merge(coerced, %{
                     body: meta.body,
                     spice_target: meta.spice_target,
                     spice_id: meta.spice_id,
                     target_kind: meta.target_kind,
                     observer: meta.observer,
                     abcorr: meta.abcorr,
                     frame_base: meta.frame_base,
                     kernel_metadata: meta.kernel_metadata
                   })}

                {:error, _} ->
                  {:error, :invalid_state_result}
              end

            {:error, _} = err ->
              err
          end

        GenServer.reply(from, reply)
        {:noreply, %{state | pending: remaining}}
    end
  end

  defp reply_to_waiter({:load_kernels, from, _meta}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter({:utc_to_et, from}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter({:state, from, _meta}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter(:clear_ack, _reply), do: :ok
  defp reply_to_waiter(nil, _reply), do: :ok

  defp call(message) do
    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, message, 30_000)
    else
      {:error, :spice_server_not_started}
    end
  end
end
