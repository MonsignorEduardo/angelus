defmodule Angelus.Observer do
  @moduledoc false

  @minimum_height_m -500.0
  @maximum_height_m 100_000.0
  @required_fields [:latitude_deg, :longitude_deg, :height_m]

  @type option ::
          {:latitude_deg, number()}
          | {:longitude_deg, number()}
          | {:height_m, number()}

  @type t :: %{
          latitude_deg: float(),
          longitude_deg: float(),
          height_m: float(),
          latitude_rad: float(),
          longitude_rad: float(),
          height_km: float()
        }

  @spec validate([option()]) :: {:ok, t()} | {:error, {:invalid_observer, term()}}
  def validate(observer) when is_list(observer) do
    with :ok <- validate_keyword_list(observer),
         :ok <- validate_fields(observer),
         {:ok, latitude_deg} <- validate_latitude(observer),
         {:ok, longitude_deg} <- validate_longitude(observer),
         {:ok, height_m} <- validate_height(observer) do
      {:ok,
       %{
         latitude_deg: latitude_deg,
         longitude_deg: longitude_deg,
         height_m: height_m,
         latitude_rad: degrees_to_radians(latitude_deg),
         longitude_rad: degrees_to_radians(longitude_deg),
         height_km: height_m / 1_000.0
       }}
    end
  end

  def validate(_observer), do: {:error, {:invalid_observer, :expected_keyword_list}}

  defp validate_keyword_list(observer) do
    if Keyword.keyword?(observer),
      do: :ok,
      else: {:error, {:invalid_observer, :expected_keyword_list}}
  end

  defp validate_fields(observer) do
    keys = Keyword.keys(observer)
    missing_fields = Enum.filter(@required_fields, &(&1 not in keys))

    cond do
      duplicate = Enum.find(@required_fields, &(Enum.count(keys, fn key -> key == &1 end) > 1)) ->
        {:error, {:invalid_observer, {:duplicate_field, duplicate}}}

      unknown = Enum.find(keys, &(&1 not in @required_fields)) ->
        {:error, {:invalid_observer, {:unsupported_field, unknown}}}

      missing_fields != [] ->
        {:error, {:invalid_observer, {:missing_fields, missing_fields}}}

      true ->
        :ok
    end
  end

  defp validate_latitude(observer) do
    value = Keyword.fetch!(observer, :latitude_deg)

    if finite_number?(value) and value >= -90.0 and value <= 90.0 do
      {:ok, value * 1.0}
    else
      {:error, {:invalid_observer, {:latitude_out_of_range, value}}}
    end
  end

  defp validate_longitude(observer) do
    value = Keyword.fetch!(observer, :longitude_deg)

    if finite_number?(value) and value >= -180.0 and value <= 180.0 do
      # Keep a single representation for the anti-meridian.
      {:ok, if(value == 180.0, do: -180.0, else: value * 1.0)}
    else
      {:error, {:invalid_observer, {:longitude_out_of_range, value}}}
    end
  end

  defp validate_height(observer) do
    value = Keyword.fetch!(observer, :height_m)

    if finite_number?(value) and value >= @minimum_height_m and value <= @maximum_height_m do
      {:ok, value * 1.0}
    else
      {:error, {:invalid_observer, {:height_out_of_range, value}}}
    end
  end

  defp finite_number?(value) when is_integer(value), do: true

  defp finite_number?(value) when is_float(value) do
    value == value and abs(value) <= 1.7976931348623157e308
  end

  defp finite_number?(_value), do: false

  defp degrees_to_radians(degrees), do: degrees * :math.pi() / 180.0
end
