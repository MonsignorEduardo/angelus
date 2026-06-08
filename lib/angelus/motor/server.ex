defmodule Angelus.Motor.Server do
  @moduledoc "GenServer that owns the native `angelus_motor` Port and serializes SPICE calls."

  use GenServer

  require Logger

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
        Logger.info("Angelus worker port opened")
        state = %{base | port: port}
        # Clear any residual CSPICE state at startup
        {id, state} = next_id(state)
        Logger.debug("Sending startup clear_kernels request", request_id: id)
        send_to_port(port, WorkerProtocol.encode_clear_kernels(id))
        {:ok, state}

      {:error, {:worker_not_found, _bin}} ->
        # Binary not compiled yet — start without a port.
        # Calls that require CSPICE will return {:error, :worker_not_available}.
        # Structural validation (whitelist, missing files, etc.) still works.
        {:ok, base}
    end
  end

  @impl true
  # load_kernels: structural validation runs before port check so whitelist
  # errors are returned even when the worker binary is absent.
  @spec handle_call(term(), GenServer.from(), map()) ::
          {:reply, term(), map()} | {:noreply, map()}
  def handle_call({:load_kernels, paths, opts}, from, state) do
    replace? = Keyword.get(opts, :replace, false)
    Logger.info("Loading SPICE kernels", replace?: replace?, kernel_count: length(paths))

    case KernelSet.validate(paths) do
      {:error, reason} ->
        Logger.warning("SPICE kernel validation failed", reason: inspect(reason))
        {:reply, {:error, reason}, state}

      {:ok, _metadata} when state.port == nil ->
        Logger.warning("SPICE worker unavailable while loading kernels")
        {:reply, {:error, :worker_not_available}, state}

      {:ok, metadata} ->
        if state.loaded? and not replace? do
          {:reply, {:error, :kernels_already_loaded}, state}
        else
          do_load_kernels(paths, metadata, replace?, from, state)
        end
    end
  end

  # body/math_point: return kernels_not_loaded when no kernels (covers nil port too)
  def handle_call({:body, _target, _utc, _opts}, _from, %{loaded?: false} = state),
    do: {:reply, {:error, :kernels_not_loaded}, state}

  def handle_call({:math_point, _point, _utc}, _from, %{loaded?: false} = state),
    do: {:reply, {:error, :kernels_not_loaded}, state}

  def handle_call({:body, target, utc, opts}, from, state) do
    iso8601 = DateTime.to_iso8601(utc)
    request_opts = body_request_opts(opts)
    {id, new_state} = next_id(state)

    Logger.debug("Requesting body state", request_id: id, target: target, utc: iso8601)
    send_to_port(state.port, WorkerProtocol.encode_body(id, target, iso8601, request_opts))

    meta = %{
      observer: request_opts.observer,
      abcorr: request_opts.abcorr,
      frame_base: request_opts.frame,
      state: request_opts.state,
      kernel_metadata: state.metadata
    }

    pending = Map.put(new_state.pending, id, {:body, from, meta})
    {:noreply, %{new_state | pending: pending}}
  end

  def handle_call({:math_point, point, utc}, from, state) do
    iso8601 = DateTime.to_iso8601(utc)
    {id, new_state} = next_id(state)

    Logger.debug("Requesting math point #{inspect(point)}", request_id: id, utc: iso8601)
    send_to_port(state.port, WorkerProtocol.encode_math_point(id, point, iso8601))

    meta = %{point: point, kernel_metadata: state.metadata}
    pending = Map.put(new_state.pending, id, {:math_point, from, meta})
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
        Logger.error("Received malformed response from Angelus worker")
        {:noreply, state}

      {:ok, id, result} ->
        Logger.debug("Received Angelus worker reply", request_id: id, result: :ok)
        handle_worker_reply(id, {:ok, result}, state)

      {:error, id, reason} ->
        Logger.warning("Received Angelus worker error", request_id: id, reason: inspect(reason))
        handle_worker_reply(id, {:error, reason}, state)
    end
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    # Worker crashed; reply worker_crashed to all pending callers
    Logger.error("Angelus worker exited",
      exit_status: status,
      pending_request_count: map_size(state.pending)
    )

    Enum.each(state.pending, fn {_id, waiter} ->
      reply_to_waiter(waiter, {:error, :worker_crashed})
    end)

    case open_port() do
      {:ok, new_port} ->
        Logger.info("Angelus worker port reopened after crash")
        {:noreply, %{state | port: new_port, pending: %{}, loaded?: false, metadata: nil}}

      {:error, _reason} ->
        Logger.error("Angelus worker port could not be reopened after crash")
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

  @doc "Combined UTC -> ET -> body state round-trip via the native worker."
  @spec body(String.t(), DateTime.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def body(target, utc, opts), do: call({:body, target, utc, opts})

  @doc "Returns a mathematical point state via the native worker."
  @spec math_point(String.t(), DateTime.t()) :: {:ok, map()} | {:error, term()}
  def math_point(point, utc), do: call({:math_point, point, utc})

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
      Logger.debug("Opening Angelus worker binary", worker_binary: bin)

      port =
        Port.open({:spawn_executable, bin}, [
          :binary,
          :exit_status,
          {:packet, 4},
          :use_stdio
        ])

      {:ok, port}
    else
      Logger.warning("Angelus worker binary not found", worker_binary: bin)
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
      Logger.debug("Sending clear_kernels request", request_id: clear_id)
      send_to_port(state1.port, WorkerProtocol.encode_clear_kernels(clear_id))

      {load_id, state2} = next_id(state1)

      Logger.debug("Sending load_kernels request",
        request_id: load_id,
        kernel_count: length(paths)
      )

      send_to_port(state2.port, WorkerProtocol.encode_load_kernels(load_id, paths))

      pending =
        state2.pending
        |> Map.put(clear_id, :clear_ack)
        |> Map.put(load_id, {:load_kernels, from, metadata})

      {:noreply, %{state2 | pending: pending, loaded?: false, metadata: nil}}
    else
      {load_id, state1} = next_id(state)

      Logger.debug("Sending load_kernels request",
        request_id: load_id,
        kernel_count: length(paths)
      )

      send_to_port(state1.port, WorkerProtocol.encode_load_kernels(load_id, paths))

      pending = Map.put(state1.pending, load_id, {:load_kernels, from, metadata})
      {:noreply, %{state1 | pending: pending}}
    end
  end

  defp handle_worker_reply(id, result, state) do
    case Map.pop(state.pending, id) do
      {nil, _} ->
        # Unexpected id (e.g. startup clear_kernels ack) — ignore
        Logger.debug("Ignoring unexpected Angelus worker reply", request_id: id)
        {:noreply, state}

      {:clear_ack, remaining} ->
        Logger.debug("Received clear_kernels ack", request_id: id)
        {:noreply, %{state | pending: remaining}}

      {{:load_kernels, from, metadata}, remaining} ->
        case result do
          {:ok, _} ->
            Logger.info("SPICE kernels loaded", request_id: id)
            GenServer.reply(from, {:ok, metadata})
            {:noreply, %{state | pending: remaining, loaded?: true, metadata: metadata}}

          {:error, reason} ->
            Logger.warning("SPICE kernel load failed", request_id: id, reason: inspect(reason))
            GenServer.reply(from, {:error, {:kernel_load_failed, reason}})
            {:noreply, %{state | pending: remaining, loaded?: false, metadata: nil}}
        end

      {{:body, from, meta}, remaining} ->
        Logger.debug("Body state completed", request_id: id)
        reply = handle_body_result(result, meta)
        GenServer.reply(from, reply)
        {:noreply, %{state | pending: remaining}}

      {{:math_point, from, meta}, remaining} ->
        Logger.debug("Math point completed", request_id: id)
        reply = handle_point_result(result, meta)
        GenServer.reply(from, reply)
        {:noreply, %{state | pending: remaining}}
    end
  end

  defp handle_body_result({:ok, raw}, meta) do
    case WorkerProtocol.coerce_body(raw) do
      {:ok, coerced} -> {:ok, Map.merge(coerced, body_metadata(meta))}
      {:error, _} -> {:error, :invalid_body_result}
    end
  end

  defp handle_body_result({:error, _} = err, _meta), do: err

  defp handle_point_result({:ok, raw}, meta) do
    case WorkerProtocol.coerce_point(raw) do
      {:ok, coerced} -> {:ok, Map.merge(coerced, point_metadata(meta))}
      {:error, _} -> {:error, :invalid_point_result}
    end
  end

  defp handle_point_result({:error, _} = err, _meta), do: err

  defp body_metadata(meta) do
    %{
      observer: meta.observer,
      abcorr: meta.abcorr,
      frame_base: meta.frame_base,
      state: meta.state,
      kernel_metadata: meta.kernel_metadata
    }
  end

  defp point_metadata(meta) do
    %{
      point: meta.point,
      kernel_metadata: meta.kernel_metadata
    }
  end

  defp body_request_opts(opts) do
    %{
      state: Keyword.get(opts, :state, :geocentric),
      observer: observer_name(Keyword.get(opts, :observer, :earth)),
      frame: frame_name(Keyword.get(opts, :frame, :eclipj2000)),
      abcorr: abcorr_name(Keyword.get(opts, :abcorr, :lt_s))
    }
  end

  defp observer_name(:earth), do: "EARTH"

  defp frame_name(:eclipj2000), do: "ECLIPJ2000"
  defp frame_name(:j2000), do: "J2000"
  defp frame_name(:icrf), do: "ICRF"
  defp frame_name(:gcrs), do: "GCRS"

  defp abcorr_name(:none), do: "NONE"
  defp abcorr_name(:lt), do: "LT"
  defp abcorr_name(:lt_s), do: "LT+S"
  defp abcorr_name(:cn), do: "CN"
  defp abcorr_name(:cn_s), do: "CN+S"

  defp reply_to_waiter({:load_kernels, from, _meta}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter({:body, from, _meta}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter({:math_point, from, _meta}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter(:clear_ack, _reply), do: :ok
  defp reply_to_waiter(nil, _reply), do: :ok

  defp call(message) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, :motor_server_not_started}

      _pid ->
        try do
          GenServer.call(__MODULE__, message, 30_000)
        catch
          :exit, {:timeout, _call} ->
            Logger.error("Angelus motor call timed out", operation: operation_name(message))
            {:error, :worker_timeout}
        end
    end
  end

  defp operation_name(message) when is_tuple(message) and tuple_size(message) > 0,
    do: elem(message, 0)

  defp operation_name(operation) when is_atom(operation), do: operation
  defp operation_name(_message), do: :unknown
end
