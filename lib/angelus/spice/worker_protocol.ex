defmodule Angelus.Spice.WorkerProtocol do
  @moduledoc """
  Encodes requests and decodes responses for the `spice_worker` Port protocol.

  Frame format (matching Erlang `packet: 4`):
    [4 bytes big-endian uint32: payload length][payload: UTF-8 JSON]

  Elixir opens the Port with `packet: 4`, so the VM handles the framing
  automatically.  This module only deals with the JSON payload layer.

  Request schema:
    %{"id" => integer, "op" => string, ...op-specific fields...}

  Response schema (success):
    %{"id" => integer, "ok" => true, "result" => term}

  Response schema (error):
    %{"id" => integer, "ok" => false, "error" => string}
  """

  @type request_id :: non_neg_integer()

  # ── Encoding ────────────────────────────────────────────────────────────

  @doc "Encodes a ping request."
  @spec encode_ping(request_id()) :: binary()
  def encode_ping(id), do: Jason.encode!(%{"id" => id, "op" => "ping"})

  @doc "Encodes a clear_kernels request."
  @spec encode_clear_kernels(request_id()) :: binary()
  def encode_clear_kernels(id),
    do: Jason.encode!(%{"id" => id, "op" => "clear_kernels"})

  @doc "Encodes a load_kernels request with explicit paths."
  @spec encode_load_kernels(request_id(), [String.t()]) :: binary()
  def encode_load_kernels(id, paths) when is_list(paths),
    do: Jason.encode!(%{"id" => id, "op" => "load_kernels", "paths" => paths})

  @doc "Encodes a load_default_kernels request."
  @spec encode_load_default_kernels(request_id(), String.t()) :: binary()
  def encode_load_default_kernels(id, base_path) when is_binary(base_path),
    do: Jason.encode!(%{"id" => id, "op" => "load_default_kernels", "base_path" => base_path})

  @doc "Encodes a utc_to_et request."
  @spec encode_utc_to_et(request_id(), String.t()) :: binary()
  def encode_utc_to_et(id, iso8601) when is_binary(iso8601),
    do: Jason.encode!(%{"id" => id, "op" => "utc_to_et", "utc" => iso8601})

  @doc """
  Encodes a state request.

  Parameters are fixed for v0.1:
    observer: "EARTH"
    frame:    "ECLIPJ2000"
    abcorr:   "LT+S"
  """
  @spec encode_state(request_id(), String.t(), float()) :: binary()
  def encode_state(id, spice_target, et)
      when is_binary(spice_target) and is_float(et),
      do:
        Jason.encode!(%{
          "id" => id,
          "op" => "state",
          "target" => spice_target,
          "et" => et,
          "observer" => "EARTH",
          "frame" => "ECLIPJ2000",
          "abcorr" => "LT+S"
        })

  @doc """
  Encodes a lunar_node request.

  `calculation` must be one of:
    - `:mean_lunar_node` — IAU 2003 polynomial (eraFaom03)
    - `:true_lunar_node` — mean node corrected with IAU 2006/2000A nutation
  """
  @spec encode_lunar_node(request_id(), :mean_lunar_node | :true_lunar_node, float()) :: binary()
  def encode_lunar_node(id, calculation, et)
      when calculation in [:mean_lunar_node, :true_lunar_node] and is_float(et),
      do:
        Jason.encode!(%{
          "id" => id,
          "op" => "lunar_node",
          "calculation" => Atom.to_string(calculation),
          "et" => et
        })

  # ── Decoding ────────────────────────────────────────────────────────────

  @doc """
  Decodes a raw binary response from the worker.

  Returns `{:ok, id, result}` or `{:error, id, reason}`.
  Returns `{:error, :decode_error, binary}` if JSON is malformed.
  """
  @spec decode(binary()) ::
          {:ok, request_id(), term()}
          | {:error, request_id(), term()}
          | {:error, :decode_error, binary()}
  @spec decode(term()) :: {:error, :decode_error, term()}
  def decode(binary) when is_binary(binary) do
    case Jason.decode(binary) do
      {:ok, %{"id" => id, "ok" => true, "result" => result}} ->
        {:ok, id, result}

      {:ok, %{"id" => id, "ok" => false, "error" => reason}} ->
        {:error, id, reason}

      {:ok, _unexpected} ->
        {:error, :decode_error, binary}

      {:error, _} ->
        {:error, :decode_error, binary}
    end
  end

  def decode(other), do: {:error, :decode_error, other}

  # ── Result coercions ────────────────────────────────────────────────────

  @doc """
  Coerces a `state` result map (string keys from JSON) into an Elixir map
  with atom keys and typed values.
  """
  @spec coerce_state(map()) :: {:ok, map()} | {:error, :invalid_state_result}
  @spec coerce_state(term()) :: {:error, :invalid_state_result}
  def coerce_state(%{
        "state_km" => [x, y, z, vx, vy, vz],
        "distance_au" => distance_au,
        "ecliptic_longitude" => longitude,
        "ecliptic_latitude" => latitude,
        "light_time_seconds" => light_time,
        "et" => et
      }) do
    {:ok,
     %{
       position_km: {x * 1.0, y * 1.0, z * 1.0},
       velocity_km_s: {vx * 1.0, vy * 1.0, vz * 1.0},
       distance_au: distance_au * 1.0,
       ecliptic_longitude: longitude * 1.0,
       ecliptic_latitude: latitude * 1.0,
       light_time_seconds: light_time * 1.0,
       et: et * 1.0
     }}
  end

  def coerce_state(_), do: {:error, :invalid_state_result}
end
