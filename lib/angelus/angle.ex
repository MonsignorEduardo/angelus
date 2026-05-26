defmodule Angelus.Angle do
  @moduledoc "Angular math helpers for normalized astrological longitudes."

  @type angle_error :: {:error, :invalid_angle}

  def normalize(angle) when is_number(angle) do
    value = angle * 1.0
    value - 360.0 * :math.floor(value / 360.0)
  end

  def normalize(_angle), do: {:error, :invalid_angle}

  def distance(a, b) when is_number(a) and is_number(b) do
    abs(signed_distance(a, b))
  end

  def distance(_a, _b), do: {:error, :invalid_angle}

  def signed_distance(a, b) when is_number(a) and is_number(b) do
    diff = normalize(b) - normalize(a)

    cond do
      diff > 180.0 -> diff - 360.0
      diff <= -180.0 -> diff + 360.0
      true -> diff
    end
  end

  def signed_distance(_a, _b), do: {:error, :invalid_angle}

  def deg_to_rad(angle) when is_number(angle), do: angle * :math.pi() / 180.0
  def deg_to_rad(_angle), do: {:error, :invalid_angle}

  def rad_to_deg(angle) when is_number(angle), do: angle * 180.0 / :math.pi()
  def rad_to_deg(_angle), do: {:error, :invalid_angle}

  def dms(angle) when is_number(angle) do
    normalized = normalize(angle)
    degree = trunc(normalized)
    minute_float = (normalized - degree) * 60.0
    minute = trunc(minute_float)
    second = (minute_float - minute) * 60.0

    {degree, minute, second}
  end

  def dms(_angle), do: {:error, :invalid_angle}
end
