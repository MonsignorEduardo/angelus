defmodule Angelus.Astro.Location do
  @moduledoc """
  Geodetic Earth location used by topocentric calculations.

  Latitude and longitude are degrees, with longitude positive eastward.
  `elevation_msl_m` is orthometric elevation in metres above mean sea level.
  Native calculations must convert it to ellipsoidal height using the configured
  geoid model before constructing an Earth-fixed observer position.
  """

  alias Angelus.Astro.Geoid

  @enforce_keys [:latitude, :longitude]
  defstruct [:latitude, :longitude, elevation_msl_m: 0.0]

  @type t :: %__MODULE__{
          latitude: number(),
          longitude: number(),
          elevation_msl_m: number()
        }

  @doc "Builds and validates a geodetic location."
  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    with true <- Keyword.keyword?(opts),
         :ok <- reject_unknown_options(opts),
         {:ok, latitude} <- Keyword.fetch(opts, :latitude),
         {:ok, longitude} <- Keyword.fetch(opts, :longitude) do
      validate(%__MODULE__{
        latitude: latitude,
        longitude: longitude,
        elevation_msl_m: Keyword.get(opts, :elevation_msl_m, 0.0)
      })
    else
      false -> {:error, :invalid_location}
      :error -> {:error, :invalid_location}
      {:error, _reason} = error -> error
    end
  end

  def new(_opts), do: {:error, :invalid_location}

  @doc "Validates a location, including structs constructed directly."
  @spec validate(term()) :: {:ok, t()} | {:error, term()}
  def validate(%__MODULE__{} = location) do
    with :ok <- validate_number(location.latitude),
         :ok <- validate_number(location.longitude),
         :ok <- validate_number(location.elevation_msl_m),
         :ok <- validate_latitude(location.latitude),
         :ok <- validate_longitude(location.longitude) do
      {:ok, location}
    end
  end

  def validate(_location), do: {:error, :invalid_location}

  @doc "Converts mean-sea-level elevation to WGS84 ellipsoidal height."
  @spec ellipsoidal_height(t(), Geoid.t()) :: {:ok, float()} | {:error, term()}
  def ellipsoidal_height(%__MODULE__{} = location, %Geoid{} = geoid) do
    with {:ok, location} <- validate(location),
         {:ok, undulation_m} <-
           Geoid.height(geoid, location.latitude, location.longitude) do
      {:ok, location.elevation_msl_m + undulation_m}
    end
  end

  def ellipsoidal_height(_location, _geoid), do: {:error, :invalid_location}

  defp reject_unknown_options(opts) do
    case Enum.find(opts, fn {key, _value} ->
           key not in [:latitude, :longitude, :elevation_msl_m]
         end) do
      nil -> :ok
      {key, _value} -> {:error, {:unsupported_location_option, key}}
    end
  end

  defp validate_number(value) when is_number(value), do: :ok
  defp validate_number(_value), do: {:error, :invalid_location}

  defp validate_latitude(latitude) when latitude >= -90 and latitude <= 90, do: :ok
  defp validate_latitude(latitude), do: {:error, {:latitude_out_of_range, latitude}}

  defp validate_longitude(longitude) when longitude >= -180 and longitude <= 180, do: :ok
  defp validate_longitude(longitude), do: {:error, {:longitude_out_of_range, longitude}}
end
