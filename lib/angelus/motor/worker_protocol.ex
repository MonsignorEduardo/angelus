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
  Encodes a body request — a single UTC->ET->state round-trip.

  Fields:
    * `target` (string) — SPICE target name
    * `utc` (string) — ISO8601 datetime
  """
  @spec encode_body(request_id(), String.t(), String.t()) :: binary()
  def encode_body(id, spice_target, iso8601)
      when is_binary(spice_target) and is_binary(iso8601) do
    Jason.encode!(%{
      "id" => id,
      "op" => "body",
      "target" => spice_target,
      "utc" => iso8601
    })
  end

  @doc "Encodes a mathematical point request."
  @spec encode_math_point(request_id(), String.t(), String.t()) :: binary()
  def encode_math_point(id, point, iso8601) when is_binary(point) and is_binary(iso8601) do
    Jason.encode!(%{
      "id" => id,
      "op" => "math_point",
      "point" => point,
      "utc" => iso8601
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
      {:ok, %{"id" => id, "ok" => true, "result" => result}}
      when is_integer(id) and id > 0 ->
        {:ok, id, result}

      {:ok, %{"id" => id, "ok" => false, "error" => reason}}
      when is_integer(id) and id > 0 and is_binary(reason) ->
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
  @spec coerce_body(map()) :: {:ok, map()} | {:error, :invalid_body_result}
  @spec coerce_body(term()) :: {:error, :invalid_body_result}
  def coerce_body(%{
        "state_km" => [x, y, z, vx, vy, vz],
        "light_time_seconds" => light_time_seconds,
        "et_seconds" => et_seconds
      })
      when is_number(x) and is_number(y) and is_number(z) and is_number(vx) and
             is_number(vy) and is_number(vz) and is_number(light_time_seconds) and
             is_number(et_seconds) do
    {:ok,
     %{
       position_km: {x * 1.0, y * 1.0, z * 1.0},
       velocity_km_s: {vx * 1.0, vy * 1.0, vz * 1.0},
       distance_au: distance_au(x, y, z),
       light_time_seconds: light_time_seconds * 1.0,
       et_seconds: et_seconds * 1.0
     }}
  end

  def coerce_body(_), do: {:error, :invalid_body_result}

  @doc "Coerces a mathematical point result map into an Elixir map."
  @spec coerce_point(map()) :: {:ok, map()} | {:error, :invalid_point_result}
  @spec coerce_point(term()) :: {:error, :invalid_point_result}
  def coerce_point(%{
        "longitude_rad" => longitude_rad,
        "speed_rad_day" => speed_rad_day,
        "et_seconds" => et_seconds
      })
      when is_number(longitude_rad) and is_number(speed_rad_day) and is_number(et_seconds) do
    {:ok,
     %{
       longitude_rad: longitude_rad * 1.0,
       speed_rad_day: speed_rad_day * 1.0,
       et_seconds: et_seconds * 1.0
     }}
  end

  def coerce_point(_), do: {:error, :invalid_point_result}

  defp distance_au(x, y, z) do
    :math.sqrt(x * x + y * y + z * z) / 149_597_870.7
  end
end
