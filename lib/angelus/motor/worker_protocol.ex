defmodule Angelus.Motor.WorkerProtocol do
  @moduledoc """
  Encodes requests and decodes responses for the `angelus_motor` Port protocol.

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

  @doc """
  Encodes an ephemeride request — a single UTC->ET->state round-trip.

  Fields:
    * `target` (string) — SPICE target name
    * `utc` (string) — ISO8601 datetime
  """
  @spec encode_ephemeride(request_id(), String.t(), String.t(), map()) :: binary()
  def encode_ephemeride(id, spice_target, iso8601, opts)
      when is_binary(spice_target) and is_binary(iso8601) and is_map(opts) do
    Jason.encode!(%{
      "id" => id,
      "op" => "ephemeride",
      "target" => spice_target,
      "utc" => iso8601,
      "observer" => opts.observer,
      "frame" => opts.frame,
      "abcorr" => opts.abcorr
    })
  end

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
        "distance_km" => distance_km,
        "distance_au" => distance_au,
        "right_ascension_rad" => right_ascension_rad,
        "declination_rad" => declination_rad,
        "ecliptic_longitude_rad" => longitude_rad,
        "ecliptic_latitude_rad" => latitude_rad,
        "radial_velocity_km_s" => radial_velocity,
        "ecliptic_longitude_speed_rad_day" => longitude_speed,
        "ecliptic_latitude_speed_rad_day" => latitude_speed,
        "distance_speed_km_s" => distance_speed,
        "light_time_seconds" => light_time,
        "et_seconds" => et_seconds,
        "frame" => frame,
        "abcorr" => abcorr
      }) do
    {:ok,
     %{
       position_km: {x * 1.0, y * 1.0, z * 1.0},
       velocity_km_s: {vx * 1.0, vy * 1.0, vz * 1.0},
       distance_km: distance_km * 1.0,
       distance_au: distance_au * 1.0,
       right_ascension_rad: right_ascension_rad * 1.0,
       declination_rad: declination_rad * 1.0,
       ecliptic_longitude_rad: longitude_rad * 1.0,
       ecliptic_latitude_rad: latitude_rad * 1.0,
       ecliptic_longitude: longitude_rad * 1.0,
       ecliptic_latitude: latitude_rad * 1.0,
       radial_velocity_km_s: radial_velocity * 1.0,
       ecliptic_longitude_speed_rad_day: longitude_speed * 1.0,
       ecliptic_latitude_speed_rad_day: latitude_speed * 1.0,
       distance_speed_km_s: distance_speed * 1.0,
       light_time_seconds: light_time * 1.0,
       et_seconds: et_seconds * 1.0,
       et: et_seconds * 1.0,
       frame: frame,
       abcorr: abcorr
     }}
  end

  def coerce_state(_), do: {:error, :invalid_state_result}
end
