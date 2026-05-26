defmodule Angelus.Ephemeris do
  @moduledoc "Public v0.1 API for geocentric ephemeris positions."

  alias Angelus.Ephemeris.BodyCatalog
  alias Angelus.Ephemeris.BodyPosition

  @range_from ~D[1900-01-01]
  @range_to ~D[2100-01-24]
  @default_adapter Angelus.Ephemeris.Adapters.Spice

  @doc """
  Returns the geocentric position of a single celestial body at a UTC datetime.

  `body` must be one of the atoms supported by the v0.1 ephemeris body catalog.
  `datetime` must be a `%DateTime{}` in the UTC timezone.

  ## Options

    * `:adapter` — an alternative ephemeris adapter module implementing the
      `Angelus.Ephemeris.Adapter` behaviour. Defaults to
      `Angelus.Ephemeris.Adapters.Spice`.

  ## Returns

    * `{:ok, %Angelus.Ephemeris.BodyPosition{}}` on success.
    * `{:error, :invalid_body}` when `body` is not an atom.
    * `{:error, :invalid_datetime}` / `{:error, :datetime_must_be_utc}` for bad datetimes.
    * `{:error, {:unsupported_body, body}}` for unrecognised bodies.
    * `{:error, {:datetime_out_of_range, %{from: Date.t(), to: Date.t()}}}` outside the
      supported range.

  ## Examples

      iex> {:ok, pos} = Angelus.Ephemeris.position(:sun, ~U[2000-01-01 12:00:00Z])
      iex> pos.body
      :sun
  """
  @spec position(atom(), DateTime.t(), keyword()) ::
          {:ok, BodyPosition.t()} | {:error, term()}
  def position(body, datetime, opts \\ [])

  def position(body, datetime, opts) when is_atom(body) do
    with {:ok, positions} <- positions([body], datetime, opts) do
      {:ok, Map.fetch!(positions, body)}
    end
  end

  def position(_body, _datetime, _opts), do: {:error, :invalid_body}

  @doc """
  Returns geocentric positions for a list of celestial bodies at a UTC datetime.

  All entries in `bodies` must be atoms supported by the v0.1 ephemeris body
  catalog. The list must be non-empty and contain no duplicates. `datetime`
  must be a `%DateTime{}` in the UTC timezone.

  ## Options

    * `:adapter` — an alternative ephemeris adapter module implementing the
      `Angelus.Ephemeris.Adapter` behaviour. Defaults to
      `Angelus.Ephemeris.Adapters.Spice`.

  ## Returns

    * `{:ok, %{atom() => %Angelus.Ephemeris.BodyPosition{}}}` — a map keyed by
      body atom.
    * `{:error, :empty_body_list}` when `bodies` is `[]`.
    * `{:error, :invalid_body_list}` when `bodies` is not a list of atoms.
    * `{:error, {:duplicate_body, atom()}}` when the same body appears more than once.
    * `{:error, {:unsupported_body, atom()}}` for unrecognised bodies.
    * `{:error, :invalid_datetime}` / `{:error, :datetime_must_be_utc}` for bad datetimes.
    * `{:error, {:datetime_out_of_range, %{from: Date.t(), to: Date.t()}}}` outside the
      supported range.
    * `{:error, {:unsupported_option, term()}}` for unknown options.

  ## Examples

      iex> {:ok, positions} = Angelus.Ephemeris.positions([:sun, :moon], ~U[2000-01-01 12:00:00Z])
      iex> Map.keys(positions)
      [:sun, :moon]
  """
  @spec positions([atom(), ...], DateTime.t(), keyword()) ::
          {:ok, %{atom() => BodyPosition.t()}} | {:error, term()}
  def positions(bodies, datetime, opts \\ []) do
    with :ok <- validate_options(opts),
         {:ok, adapter} <- fetch_adapter(opts),
         :ok <- validate_datetime(datetime),
         :ok <- validate_body_list_shape(bodies),
         :ok <- validate_duplicates(bodies),
         :ok <- validate_supported_bodies(bodies),
         :ok <- validate_public_range(datetime),
         {:ok, et} <- adapter.utc_to_et(datetime) do
      build_positions(bodies, et, adapter)
    end
  end

  defp build_positions(bodies, et, adapter) do
    Enum.reduce_while(bodies, {:ok, %{}}, fn body, {:ok, acc} ->
      case build_position(body, et, adapter) do
        {:ok, position} -> {:cont, {:ok, Map.put(acc, body, position)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp build_position(body, et, adapter) do
    with {:ok, state} <- adapter.state(body, et) do
      longitude = Angelus.Angle.normalize(state.ecliptic_longitude)

      {:ok,
       %BodyPosition{
         body: body,
         spice_target: state.spice_target,
         spice_id: state.spice_id,
         target_kind: state.target_kind,
         position_km: state.position_km,
         velocity_km_s: state.velocity_km_s,
         light_time_seconds: state.light_time_seconds,
         longitude: longitude,
         latitude: state.ecliptic_latitude,
         distance_au: state.distance_au,
         metadata: metadata(state, adapter)
       }}
    end
  end

  defp metadata(state, adapter) do
    kernel_metadata = state.kernel_metadata || %{}

    %{
      engine: :spice,
      adapter: adapter,
      ephemeris: Map.get(kernel_metadata, :ephemeris),
      kernel_policy: Map.get(kernel_metadata, :kernel_policy),
      kernels: Map.get(kernel_metadata, :kernels),
      public_range: Map.get(kernel_metadata, :public_range, %{from: @range_from, to: @range_to}),
      spice_target: state.spice_target,
      spice_id: state.spice_id,
      target_kind: state.target_kind,
      observer: "EARTH",
      abcorr: "LT+S",
      frame_base: "ECLIPJ2000",
      angelus_version: Angelus.version()
    }
  end

  defp validate_options(opts) when is_list(opts) do
    case Enum.find(opts, fn
           {:adapter, _adapter} -> false
           _option -> true
         end) do
      nil -> :ok
      option -> {:error, {:unsupported_option, option}}
    end
  end

  defp validate_options(option), do: {:error, {:unsupported_option, option}}

  defp fetch_adapter(opts) do
    adapter = Keyword.get(opts, :adapter, @default_adapter)

    cond do
      adapter == @default_adapter ->
        {:ok, adapter}

      valid_adapter?(adapter) ->
        {:ok, adapter}

      true ->
        {:error, {:invalid_adapter, adapter}}
    end
  end

  defp valid_adapter?(adapter) when is_atom(adapter) do
    Code.ensure_loaded?(adapter) and function_exported?(adapter, :utc_to_et, 1) and
      function_exported?(adapter, :state, 2)
  end

  defp valid_adapter?(_adapter), do: false

  defp validate_datetime(%DateTime{time_zone: "Etc/UTC", utc_offset: 0, std_offset: 0}), do: :ok
  defp validate_datetime(%DateTime{}), do: {:error, :datetime_must_be_utc}
  defp validate_datetime(_datetime), do: {:error, :invalid_datetime}

  defp validate_body_list_shape([]), do: {:error, :empty_body_list}

  defp validate_body_list_shape(bodies) when is_list(bodies) do
    if Enum.all?(bodies, &is_atom/1), do: :ok, else: {:error, :invalid_body_list}
  end

  defp validate_body_list_shape(_bodies), do: {:error, :invalid_body_list}

  defp validate_duplicates(bodies) do
    case Enum.find(bodies, &(Enum.count(bodies, fn body -> body == &1 end) > 1)) do
      nil -> :ok
      body -> {:error, {:duplicate_body, body}}
    end
  end

  defp validate_supported_bodies(bodies) do
    case Enum.find(bodies, fn body ->
           match?({:error, _reason}, BodyCatalog.fetch(body))
         end) do
      nil -> :ok
      body -> {:error, {:unsupported_body, body}}
    end
  end

  defp validate_public_range(%DateTime{} = datetime) do
    date = DateTime.to_date(datetime)

    if Date.compare(date, @range_from) in [:eq, :gt] and
         Date.compare(date, @range_to) in [:eq, :lt] do
      :ok
    else
      {:error, {:datetime_out_of_range, %{from: @range_from, to: @range_to}}}
    end
  end
end
