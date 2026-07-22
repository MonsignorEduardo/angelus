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
  @protocol_version 2

  @doc "Returns the protocol version implemented by this package."
  @spec protocol_version() :: pos_integer()
  def protocol_version, do: @protocol_version

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

  @doc "Encodes a protocol v2 body request with an optional surface observer."
  @spec encode_body(request_id(), String.t(), String.t(), Angelus.Observer.t() | nil) :: binary()
  def encode_body(id, spice_target, iso8601, observer)
      when is_binary(spice_target) and is_binary(iso8601) and
             (is_map(observer) or is_nil(observer)) do
    request = %{
      "protocol_version" => @protocol_version,
      "id" => id,
      "op" => "body",
      "target" => spice_target,
      "utc" => iso8601
    }

    request =
      if observer do
        Map.put(request, "observer", %{
          "kind" => "surface",
          "latitude_rad" => observer.latitude_rad,
          "longitude_rad" => observer.longitude_rad,
          "height_km" => observer.height_km,
          "body_fixed_frame" => "ITRF93"
        })
      else
        request
      end

    Jason.encode!(request)
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
  def coerce_body(
        %{
          "protocol_version" => 2,
          "et_seconds" => et_seconds,
          "geocentric" => geocentric
        } = result
      )
      when is_number(et_seconds) do
    with {:ok, geocentric} <- coerce_body_solution(geocentric, et_seconds),
         {:ok, topocentric} <- coerce_topocentric_solution(result, et_seconds) do
      {:ok, %{geocentric: geocentric, topocentric: topocentric}}
    end
  end

  def coerce_body(%{
        "state_km" => [x, y, z, vx, vy, vz],
        "light_time_seconds" => light_time_seconds,
        "et_seconds" => et_seconds,
        "longitude_rad" => longitude_rad,
        "latitude_rad" => latitude_rad,
        "declination_rad" => declination_rad
      }) do
    values = [
      x,
      y,
      z,
      vx,
      vy,
      vz,
      light_time_seconds,
      et_seconds,
      longitude_rad,
      latitude_rad,
      declination_rad
    ]

    if Enum.all?(values, &is_number/1) do
      {:ok,
       %{
         position_km: {x * 1.0, y * 1.0, z * 1.0},
         velocity_km_s: {vx * 1.0, vy * 1.0, vz * 1.0},
         distance_au: distance_au(x, y, z),
         light_time_seconds: light_time_seconds * 1.0,
         et_seconds: et_seconds * 1.0,
         longitude_rad: longitude_rad * 1.0,
         latitude_rad: latitude_rad * 1.0,
         longitude: longitude_rad * 180.0 / :math.pi(),
         latitude: latitude_rad * 180.0 / :math.pi(),
         declination_rad: declination_rad * 1.0,
         declination: declination_rad * 180.0 / :math.pi(),
         direction_j2000: direction(x, y, z),
         right_ascension_rad: longitude_rad * 1.0,
         longitude_rate_rad_day: 0.0,
         latitude_rate_rad_day: 0.0,
         right_ascension_rate_rad_day: 0.0,
         declination_rate_rad_day: 0.0,
         radial_velocity_km_s: radial_velocity(x, y, z, vx, vy, vz)
       }}
    else
      {:error, :invalid_body_result}
    end
  end

  def coerce_body(_), do: {:error, :invalid_body_result}

  defp coerce_topocentric_solution(%{"topocentric" => topocentric}, et_seconds),
    do: coerce_topocentric_enu_solution(topocentric, et_seconds)

  defp coerce_topocentric_solution(_result, _et_seconds), do: {:ok, nil}

  defp coerce_body_solution(solution, et_seconds) when is_map(solution) do
    with {:ok, body} <- solution |> Map.put("et_seconds", et_seconds) |> coerce_body(),
         {:ok, scientific} <- coerce_scientific_fields(solution) do
      {:ok, Map.merge(body, scientific)}
    end
  end

  defp coerce_body_solution(_solution, _et_seconds), do: {:error, :invalid_body_result}

  defp coerce_topocentric_enu_solution(
         %{
           "state_km" => [x, y, z, vx, vy, vz],
           "light_time_seconds" => light_time_seconds,
           "frame" => "TOPOCENTRIC_ENU",
           "observer" => "SURFACE_LOCATION",
           "observer_frame" => "ITRF93",
           "abcorr" => "CN+S"
         },
         et_seconds
       ) do
    values = [x, y, z, vx, vy, vz, light_time_seconds, et_seconds]

    if Enum.all?(values, &is_number/1) do
      {:ok,
       %{
         position_km: {x * 1.0, y * 1.0, z * 1.0},
         velocity_km_s: {vx * 1.0, vy * 1.0, vz * 1.0},
         light_time_seconds: light_time_seconds * 1.0,
         et_seconds: et_seconds * 1.0,
         frame: :topocentric_enu
       }}
    else
      {:error, :invalid_body_result}
    end
  end

  defp coerce_topocentric_enu_solution(_solution, _et_seconds),
    do: {:error, :invalid_body_result}

  defp coerce_scientific_fields(%{
         "direction_j2000" => [direction_x, direction_y, direction_z],
         "right_ascension_rad" => right_ascension_rad,
         "longitude_rate_rad_day" => longitude_rate_rad_day,
         "latitude_rate_rad_day" => latitude_rate_rad_day,
         "right_ascension_rate_rad_day" => right_ascension_rate_rad_day,
         "declination_rate_rad_day" => declination_rate_rad_day,
         "distance_au" => distance_au,
         "radial_velocity_km_s" => radial_velocity_km_s
       }) do
    values = [
      direction_x,
      direction_y,
      direction_z,
      right_ascension_rad,
      longitude_rate_rad_day,
      latitude_rate_rad_day,
      right_ascension_rate_rad_day,
      declination_rate_rad_day,
      distance_au,
      radial_velocity_km_s
    ]

    if Enum.all?(values, &is_number/1) do
      {:ok,
       %{
         direction_j2000: {direction_x * 1.0, direction_y * 1.0, direction_z * 1.0},
         right_ascension_rad: right_ascension_rad * 1.0,
         longitude_rate_rad_day: longitude_rate_rad_day * 1.0,
         latitude_rate_rad_day: latitude_rate_rad_day * 1.0,
         right_ascension_rate_rad_day: right_ascension_rate_rad_day * 1.0,
         declination_rate_rad_day: declination_rate_rad_day * 1.0,
         distance_au: distance_au * 1.0,
         radial_velocity_km_s: radial_velocity_km_s * 1.0
       }}
    else
      {:error, :invalid_body_result}
    end
  end

  defp coerce_scientific_fields(_solution), do: {:error, :invalid_body_result}

  @doc "Coerces a mathematical point result map into an Elixir map."
  @spec coerce_point(map()) :: {:ok, map()} | {:error, :invalid_point_result}
  @spec coerce_point(term()) :: {:error, :invalid_point_result}
  def coerce_point(%{
        "longitude_rad" => longitude_rad,
        "declination_rad" => declination_rad,
        "speed_rad_day" => speed_rad_day,
        "et_seconds" => et_seconds
      })
      when is_number(longitude_rad) and is_number(declination_rad) and
             is_number(speed_rad_day) and is_number(et_seconds) do
    {:ok,
     %{
       longitude_rad: longitude_rad * 1.0,
       declination_rad: declination_rad * 1.0,
       declination: declination_rad * 180.0 / :math.pi(),
       speed_rad_day: speed_rad_day * 1.0,
       et_seconds: et_seconds * 1.0
     }}
  end

  def coerce_point(_), do: {:error, :invalid_point_result}

  defp distance_au(x, y, z) do
    :math.sqrt(x * x + y * y + z * z) / 149_597_870.7
  end

  defp direction(x, y, z) do
    norm = :math.sqrt(x * x + y * y + z * z)
    {x / norm, y / norm, z / norm}
  end

  defp radial_velocity(x, y, z, vx, vy, vz) do
    (x * vx + y * vy + z * vz) / :math.sqrt(x * x + y * y + z * z)
  end
end
