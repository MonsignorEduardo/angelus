defmodule Angelus.Motor.Server do
  @moduledoc "GenServer that owns the native `angelus_motor` Port and serializes SPICE calls."

  use GenServer

  import Bitwise, only: [band: 2]

  require Logger

  alias Angelus.Motor.KernelSet
  alias Angelus.Motor.WorkerProtocol

  @worker_bin "angelus_worker"
  @request_timeout 29_000
  @reopen_base_delay 100
  @reopen_max_delay 5_000

  # ── GenServer ────────────────────────────────────────────────────────────

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(_opts) do
    base = %{
      port: nil,
      next_id: 1,
      pending: %{},
      kernel_state: :unloaded,
      metadata: nil,
      reopen_attempt: 0,
      reopen_timer: nil
    }

    case open_port() do
      {:ok, port} ->
        Logger.info("Angelus worker port opened")
        state = %{base | port: port}
        # Clear any residual CSPICE state at startup
        {id, state} = next_id(state)
        Logger.debug("Sending startup clear_kernels request", request_id: id)

        case send_to_port(port, WorkerProtocol.encode_clear_kernels(id)) do
          :ok -> {:ok, state}
          {:error, _reason} -> {:ok, restart_worker(state, {:error, :worker_write_failed})}
        end

      {:error, _reason} ->
        # Binary not compiled yet — start without a port.
        # Calls that require CSPICE will return {:error, :worker_not_available}.
        # Structural validation (whitelist, missing files, etc.) still works.
        {:ok, schedule_reopen(base)}
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
        case state.kernel_state do
          state_name when state_name in [:loading, :replacing] ->
            {:reply, {:error, :kernel_operation_in_progress}, state}

          :loaded when not replace? ->
            {:reply, {:error, :kernels_already_loaded}, state}

          _state_name ->
            do_load_kernels(paths, metadata, replace?, from, state)
        end
    end
  end

  # body/math_point: return kernels_not_loaded when no kernels (covers nil port too)
  def handle_call({:body, _target, _utc}, _from, %{kernel_state: state_name} = state)
      when state_name != :loaded,
      do: {:reply, {:error, :kernels_not_loaded}, state}

  def handle_call({:math_point, _point, _utc}, _from, %{kernel_state: state_name} = state)
      when state_name != :loaded,
      do: {:reply, {:error, :kernels_not_loaded}, state}

  def handle_call({:body, target, utc}, from, state) do
    iso8601 = DateTime.to_iso8601(utc)
    {id, new_state} = next_id(state)

    Logger.debug("Requesting body state", request_id: id, target: target, utc: iso8601)

    meta = %{
      observer: "EARTH",
      abcorr: "CN+S",
      frame_base: "ECLIPJ2000",
      state: :geocentric,
      kernel_metadata: state.metadata
    }

    case send_to_port(state.port, WorkerProtocol.encode_body(id, target, iso8601)) do
      :ok ->
        {:noreply, put_pending(new_state, id, %{kind: :body, from: from, meta: meta})}

      {:error, reason} ->
        Logger.error("Failed to write body request to worker", reason: inspect(reason))

        {:reply, {:error, :worker_write_failed},
         restart_worker(state, {:error, :worker_restarted})}
    end
  end

  def handle_call({:math_point, point, utc}, from, state) do
    iso8601 = DateTime.to_iso8601(utc)
    {id, new_state} = next_id(state)

    Logger.debug("Requesting math point #{inspect(point)}", request_id: id, utc: iso8601)
    meta = %{point: point, kernel_metadata: state.metadata}

    case send_to_port(state.port, WorkerProtocol.encode_math_point(id, point, iso8601)) do
      :ok ->
        {:noreply, put_pending(new_state, id, %{kind: :math_point, from: from, meta: meta})}

      {:error, reason} ->
        Logger.error("Failed to write math point request to worker", reason: inspect(reason))

        {:reply, {:error, :worker_write_failed},
         restart_worker(state, {:error, :worker_restarted})}
    end
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
        Logger.error("Received malformed response from Angelus worker")
        {:noreply, restart_worker(state, {:error, :worker_protocol_error})}

      {:ok, id, result} ->
        Logger.debug("Received Angelus worker reply", request_id: id, result: :ok)
        handle_worker_reply(id, {:ok, result}, %{state | reopen_attempt: 0})

      {:error, id, reason} ->
        Logger.warning("Received Angelus worker error", request_id: id, reason: inspect(reason))
        handle_worker_reply(id, {:error, reason}, %{state | reopen_attempt: 0})
    end
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    # Worker crashed; reply worker_crashed to all pending callers
    Logger.error("Angelus worker exited",
      exit_status: status,
      pending_request_count: map_size(state.pending)
    )

    Enum.each(state.pending, fn {_id, waiter} ->
      Process.cancel_timer(waiter.timer)
      reply_to_waiter(waiter, {:error, :worker_crashed})
    end)

    clean_state = %{state | port: nil, pending: %{}, kernel_state: :unloaded, metadata: nil}
    {:noreply, schedule_reopen(clean_state)}
  end

  def handle_info({:request_timeout, id}, state) do
    case Map.fetch(state.pending, id) do
      :error ->
        {:noreply, state}

      {:ok, waiter} ->
        Logger.error("Angelus worker request timed out", request_id: id, operation: waiter.kind)
        reply_to_waiter(waiter, {:error, :worker_timeout})
        remaining = Map.delete(state.pending, id)
        {:noreply, restart_worker(%{state | pending: remaining}, {:error, :worker_restarted})}
    end
  end

  def handle_info(:reopen_port, %{port: nil} = state) do
    {:noreply, reopen_or_schedule(%{state | reopen_timer: nil})}
  end

  def handle_info(:reopen_port, state), do: {:noreply, %{state | reopen_timer: nil}}

  def handle_info(_msg, state), do: {:noreply, state}

  # ── Public API ───────────────────────────────────────────────────────────

  @doc "Starts the named Motor server process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Loads validated kernel paths into the native worker."
  @spec load_kernels([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def load_kernels(paths, opts), do: call({:load_kernels, paths, opts})

  @doc "Combined UTC -> ET -> body state round-trip via the native worker."
  @spec get_body(String.t(), DateTime.t()) :: {:ok, map()} | {:error, term()}
  def get_body(target, utc), do: call({:body, target, utc})

  @doc "Returns a mathematical point state via the native worker."
  @spec get_math_point(String.t(), DateTime.t()) :: {:ok, map()} | {:error, term()}
  def get_math_point(point, utc), do: call({:math_point, point, utc})

  @doc "Returns metadata for the currently loaded kernel set, if any."
  @spec metadata() :: {:ok, map() | nil}
  def metadata, do: call(:metadata)

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp next_id(%{next_id: id} = state) do
    {id, %{state | next_id: id + 1}}
  end

  defp open_port do
    bin = worker_bin_path()

    with {:ok, stat} <- File.stat(bin),
         true <- stat.type == :regular,
         true <- band(stat.mode, 0o111) != 0 do
      Logger.debug("Opening Angelus worker binary", worker_binary: bin)

      try do
        {:ok,
         Port.open({:spawn_executable, bin}, [
           :binary,
           :exit_status,
           {:packet, 4},
           :use_stdio
         ])}
      rescue
        error in [ArgumentError, ErlangError] ->
          Logger.error("Angelus worker could not be opened",
            worker_binary: bin,
            reason: Exception.message(error)
          )

          {:error, {:worker_open_failed, bin}}
      end
    else
      {:error, :enoent} ->
        Logger.warning("Angelus worker binary not found", worker_binary: bin)
        {:error, {:worker_not_found, bin}}

      {:error, reason} ->
        Logger.error("Angelus worker binary could not be inspected",
          worker_binary: bin,
          reason: inspect(reason)
        )

        {:error, {:worker_unavailable, bin}}

      false ->
        Logger.error("Angelus worker binary is not executable", worker_binary: bin)
        {:error, {:worker_not_executable, bin}}
    end
  end

  defp worker_bin_path do
    case :code.priv_dir(:angelus) do
      {:error, _} -> Path.join(["priv", @worker_bin])
      priv_dir -> Path.join(List.to_string(priv_dir), @worker_bin)
    end
  end

  defp send_to_port(port, json) when is_port(port) and is_binary(json) do
    if Port.command(port, json), do: :ok, else: {:error, :port_closed}
  rescue
    ArgumentError -> {:error, :port_closed}
  end

  defp send_to_port(_port, _json), do: {:error, :port_unavailable}

  defp do_load_kernels(paths, metadata, replace?, from, state) do
    if replace? do
      {clear_id, state1} = next_id(state)
      Logger.debug("Sending clear_kernels request", request_id: clear_id)

      case send_to_port(state1.port, WorkerProtocol.encode_clear_kernels(clear_id)) do
        :ok ->
          waiter = %{
            kind: :replace_clear,
            from: from,
            paths: paths,
            metadata: metadata
          }

          {:noreply, %{put_pending(state1, clear_id, waiter) | kernel_state: :replacing}}

        {:error, reason} ->
          Logger.error("Failed to write clear request to worker", reason: inspect(reason))

          {:reply, {:error, :worker_write_failed},
           restart_worker(state, {:error, :worker_restarted})}
      end
    else
      case send_load_request(%{state | kernel_state: :loading}, paths, metadata, from) do
        {:ok, new_state} ->
          {:noreply, new_state}

        {:error, reason, failed_state} ->
          Logger.error("Failed to write load request to worker", reason: inspect(reason))

          {:reply, {:error, :worker_write_failed},
           restart_worker(failed_state, {:error, :worker_restarted})}
      end
    end
  end

  defp handle_worker_reply(id, result, state) do
    case pop_pending(state.pending, id) do
      {nil, _} ->
        # Unexpected id (e.g. startup clear_kernels ack) — ignore
        Logger.debug("Ignoring unexpected Angelus worker reply", request_id: id)
        {:noreply, state}

      {waiter, remaining} ->
        handle_pending_reply(waiter, result, id, remaining, state)
    end
  end

  defp handle_pending_reply(%{kind: :replace_clear} = waiter, result, id, remaining, state) do
    case result do
      {:ok, _} ->
        Logger.debug("Received clear_kernels ack", request_id: id)

        case send_load_request(
               %{state | pending: remaining, metadata: nil},
               waiter.paths,
               waiter.metadata,
               waiter.from,
               waiter.deadline
             ) do
          {:ok, new_state} ->
            {:noreply, new_state}

          {:error, reason, failed_state} ->
            Logger.error("Failed to write replacement load request", reason: inspect(reason))
            GenServer.reply(waiter.from, {:error, :worker_write_failed})
            {:noreply, restart_worker(failed_state, {:error, :worker_restarted})}
        end

      {:error, reason} ->
        Logger.warning("SPICE kernel clear failed", request_id: id, reason: inspect(reason))
        GenServer.reply(waiter.from, {:error, {:kernel_clear_failed, reason}})
        {:noreply, restart_worker(%{state | pending: remaining}, {:error, :worker_restarted})}
    end
  end

  defp handle_pending_reply(
         %{kind: :load_kernels, from: from, meta: metadata},
         result,
         id,
         remaining,
         state
       ) do
    case result do
      {:ok, _} ->
        Logger.info("SPICE kernels loaded", request_id: id)
        GenServer.reply(from, {:ok, metadata})
        {:noreply, %{state | pending: remaining, kernel_state: :loaded, metadata: metadata}}

      {:error, reason} ->
        Logger.warning("SPICE kernel load failed", request_id: id, reason: inspect(reason))
        GenServer.reply(from, {:error, {:kernel_load_failed, reason}})
        {:noreply, %{state | pending: remaining, kernel_state: :unloaded, metadata: nil}}
    end
  end

  defp handle_pending_reply(%{kind: :body, from: from, meta: meta}, result, id, remaining, state) do
    Logger.debug("Body state completed", request_id: id)
    GenServer.reply(from, handle_body_result(result, meta))
    {:noreply, %{state | pending: remaining}}
  end

  defp handle_pending_reply(
         %{kind: :math_point, from: from, meta: meta},
         result,
         id,
         remaining,
         state
       ) do
    Logger.debug("Math point completed", request_id: id)
    GenServer.reply(from, handle_point_result(result, meta))
    {:noreply, %{state | pending: remaining}}
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

  defp reply_to_waiter(%{from: from}, reply), do: GenServer.reply(from, reply)
  defp reply_to_waiter(nil, _reply), do: :ok

  defp send_load_request(state, paths, metadata, from, deadline \\ nil) do
    {id, new_state} = next_id(state)

    Logger.debug("Sending load_kernels request", request_id: id, kernel_count: length(paths))

    case send_to_port(new_state.port, WorkerProtocol.encode_load_kernels(id, paths)) do
      :ok ->
        waiter = %{kind: :load_kernels, from: from, meta: metadata}
        waiter = if deadline, do: Map.put(waiter, :deadline, deadline), else: waiter
        {:ok, put_pending(new_state, id, waiter)}

      {:error, reason} ->
        {:error, reason, new_state}
    end
  end

  defp put_pending(state, id, waiter) do
    now = System.monotonic_time(:millisecond)
    deadline = Map.get(waiter, :deadline, now + @request_timeout)
    timer = Process.send_after(self(), {:request_timeout, id}, max(deadline - now, 0))
    waiter = Map.merge(waiter, %{deadline: deadline, timer: timer})
    %{state | pending: Map.put(state.pending, id, waiter)}
  end

  defp pop_pending(pending, id) do
    case Map.pop(pending, id) do
      {nil, remaining} ->
        {nil, remaining}

      {%{timer: timer} = waiter, remaining} ->
        Process.cancel_timer(timer)
        {Map.delete(waiter, :timer), remaining}
    end
  end

  defp restart_worker(state, pending_reply) do
    Enum.each(state.pending, fn {_id, waiter} ->
      Process.cancel_timer(waiter.timer)
      reply_to_waiter(waiter, pending_reply)
    end)

    close_port(state.port)

    state
    |> Map.merge(%{port: nil, pending: %{}, kernel_state: :unloaded, metadata: nil})
    |> reopen_or_schedule()
  end

  defp reopen_or_schedule(state) do
    case open_port() do
      {:ok, port} ->
        if state.reopen_timer, do: Process.cancel_timer(state.reopen_timer)
        Logger.info("Angelus worker port opened")
        %{state | port: port, reopen_timer: nil}

      {:error, _reason} ->
        schedule_reopen(%{state | port: nil})
    end
  end

  defp schedule_reopen(%{reopen_timer: timer} = state) when is_reference(timer), do: state

  defp schedule_reopen(state) do
    exponent = min(state.reopen_attempt, 6)
    delay = min(@reopen_base_delay * Integer.pow(2, exponent), @reopen_max_delay)
    timer = Process.send_after(self(), :reopen_port, delay)
    %{state | reopen_attempt: state.reopen_attempt + 1, reopen_timer: timer}
  end

  defp close_port(nil), do: :ok

  defp close_port(port) do
    Port.close(port)
  rescue
    ArgumentError -> :ok
  end

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
