defmodule Angelus.Angle do
  @moduledoc "Angular math helpers for normalized astrological longitudes."

  @type angle_error :: {:error, :invalid_angle}

  @doc """
  Normalizes an angle to the range `[0.0, 360.0)`.

  Returns `{:error, :invalid_angle}` when the value is not a number.

  ## Examples

      iex> Angelus.Angle.normalize(370.0)
      10.0

      iex> Angelus.Angle.normalize(-10.0)
      350.0
  """
  @spec normalize(number()) :: float()
  @spec normalize(term()) :: angle_error()
  def normalize(angle) when is_number(angle) do
    value = angle * 1.0
    value - 360.0 * :math.floor(value / 360.0)
  end

  def normalize(_angle), do: {:error, :invalid_angle}

  @doc """
  Returns the absolute angular distance between two angles in degrees.

  The result is always in `[0.0, 180.0]`. Returns `{:error, :invalid_angle}`
  if either argument is not a number.

  ## Examples

      iex> Angelus.Angle.distance(10.0, 350.0)
      20.0
  """
  @spec distance(number(), number()) :: float()
  @spec distance(term(), term()) :: angle_error()
  def distance(a, b) when is_number(a) and is_number(b) do
    abs(signed_distance(a, b))
  end

  def distance(_a, _b), do: {:error, :invalid_angle}

  @doc """
  Returns the shortest signed angular distance from `a` to `b` in degrees.

  The result is in `(-180.0, 180.0]`. A positive value means `b` is ahead of
  `a` in the counter-clockwise direction. Returns `{:error, :invalid_angle}` if
  either argument is not a number.

  ## Examples

      iex> Angelus.Angle.signed_distance(10.0, 350.0)
      -20.0

      iex> Angelus.Angle.signed_distance(350.0, 10.0)
      20.0
  """
  @spec signed_distance(number(), number()) :: float()
  @spec signed_distance(term(), term()) :: angle_error()
  def signed_distance(a, b) when is_number(a) and is_number(b) do
    diff = normalize(b) - normalize(a)

    cond do
      diff > 180.0 -> diff - 360.0
      diff <= -180.0 -> diff + 360.0
      true -> diff
    end
  end

  def signed_distance(_a, _b), do: {:error, :invalid_angle}

  @doc """
  Converts degrees to radians.

  Returns `{:error, :invalid_angle}` when the value is not a number.

  ## Examples

      iex> Angelus.Angle.deg_to_rad(180.0)
      :math.pi()
  """
  @spec deg_to_rad(number()) :: float()
  @spec deg_to_rad(term()) :: angle_error()
  def deg_to_rad(angle) when is_number(angle), do: angle * :math.pi() / 180.0
  def deg_to_rad(_angle), do: {:error, :invalid_angle}

  @doc """
  Converts radians to degrees.

  Returns `{:error, :invalid_angle}` when the value is not a number.

  ## Examples

      iex> Angelus.Angle.rad_to_deg(:math.pi())
      180.0
  """
  @spec rad_to_deg(number()) :: float()
  @spec rad_to_deg(term()) :: angle_error()
  def rad_to_deg(angle) when is_number(angle), do: angle * 180.0 / :math.pi()
  def rad_to_deg(_angle), do: {:error, :invalid_angle}

  @doc """
  Decomposes an angle into degrees, minutes, and seconds.

  The input is first normalized to `[0.0, 360.0)` before decomposition.
  Returns `{:error, :invalid_angle}` when the value is not a number.

  ## Examples

      iex> Angelus.Angle.dms(90.5)
      {90, 30, 0.0}
  """
  @spec dms(number()) :: {non_neg_integer(), non_neg_integer(), float()}
  @spec dms(term()) :: angle_error()
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
