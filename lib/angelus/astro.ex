defmodule Angelus.Astro do
  @moduledoc "Public v0.1 API for astronomical body states and mathematical points."

  alias Angelus.Astro.Body
  alias Angelus.Astro.Point

  @range_from ~D[1900-01-01]
  @range_to ~D[2100-01-24]
  @default_adapter Angelus.Astro.Adapters.Spice

  @typedoc """
  Ephemeris adapter module implementing `get_ephemeride/3`.
  """
  @type adapter :: module()

  @typedoc """
  Keyword option accepted by `positions/3` and `Angelus.position/3`.

  Callers normally pass `[]`. `:adapter` defaults to
  `Angelus.Astro.Adapters.Spice`. With that adapter, the forwarded SPICE
  options default to `state: :geocentric`, `observer: :earth`,
  `frame: :eclipj2000`, and `abcorr: :lt_s`.

  Unsupported options return `{:error, {:unsupported_option, option}}`.
  """
  @type option :: {:adapter, adapter()} | Angelus.Motor.body_option()

  @typedoc """
  Keyword options accepted by `positions/3` and `Angelus.position/3`.
  """
  @type options :: [option()]

  @doc """
  Returns geocentric positions for a list of celestial bodies at a UTC datetime.

  All entries in `bodies` must be atoms supported by the v0.1 ephemeris body
  catalog. The list must be non-empty and contain no duplicates. `datetime`
  must be a `%DateTime{}` in the UTC timezone.

  ## Options

    * `:adapter` — an alternative ephemeris adapter module implementing the
      `Angelus.Astro.Adapter` behaviour. Defaults to
      `Angelus.Astro.Adapters.Spice`.
    * `:state`, `:observer`, `:frame`, and `:abcorr` — forwarded to the adapter.
      With the default SPICE adapter, these default to `:geocentric`, `:earth`,
      `:eclipj2000`, and `:lt_s`, respectively.

  See `t:options/0` for the accepted keyword entries.

  ## Returns

    * `{:ok, %{atom() => %Angelus.Astro.Body{} | %Angelus.Astro.Point{}}}` — a map keyed by
      body/point atom.
    * `{:error, :empty_body_list}` when `bodies` is `[]`.
    * `{:error, :invalid_body_list}` when `bodies` is not a list of atoms.
    * `{:error, {:duplicate_body, atom()}}` when the same body appears more than once.
    * `{:error, {:unsupported_body, atom()}}` for unrecognised bodies.
    * `{:error, :invalid_datetime}` / `{:error, :datetime_must_be_utc}` for bad datetimes.
    * `{:error, {:datetime_out_of_range, %{from: Date.t(), to: Date.t()}}}` outside the
      supported range.
    * `{:error, {:unsupported_option, term()}}` for unknown options.

  ## Examples

      iex> {:ok, positions} = Angelus.Astro.positions([:sun, :moon], ~U[2000-01-01 12:00:00Z])
      iex> Map.keys(positions)
      [:sun, :moon]
  """
  @spec positions([atom(), ...], DateTime.t(), options()) ::
          {:ok, %{atom() => Body.t() | Point.t()}} | {:error, term()}
  def positions(bodies, datetime, opts \\ []) do
    with :ok <- validate_options(opts),
         :ok <- validate_datetime(datetime),
         :ok <- validate_body_list_shape(bodies),
         :ok <- validate_duplicates(bodies),
         :ok <- validate_public_range(datetime),
         {:ok, adapter} <- fetch_adapter(opts) do
      build_positions(bodies, datetime, adapter, opts)
    end
  end

  defp build_positions(bodies, datetime, adapter, opts) do
    Enum.reduce_while(bodies, {:ok, %{}}, fn body, {:ok, acc} ->
      case adapter.get_ephemeride(datetime, body, opts) do
        {:ok, position} -> {:cont, {:ok, Map.put(acc, body, position)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_options(opts) when is_list(opts) do
    allowed_keys = [:adapter, :state, :observer, :frame, :abcorr]

    case Enum.find(opts, fn {key, _value} -> key not in allowed_keys end) do
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
    Code.ensure_loaded?(adapter) and function_exported?(adapter, :get_ephemeride, 3)
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
