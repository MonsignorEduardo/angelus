defmodule Angelus.Astro do
  @moduledoc false

  alias Angelus.Astro.Body
  alias Angelus.Astro.Point

  @range_from ~D[1900-01-01]
  @range_to ~D[2100-01-24]

  @typedoc """
  Ephemeris adapter module implementing position callbacks.
  """
  @type adapter :: module()

  @doc """
  Returns geocentric positions for a list of celestial bodies at a UTC datetime.

  All entries in `bodies` must be atoms supported by the v0.1 ephemeris body
  catalog. The list must be non-empty and contain no duplicates. `datetime`
  must be a `%DateTime{}` in the UTC timezone.

  `adapter` must implement the `Angelus.Astro.Adapter` behaviour.

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
    * `{:error, {:invalid_adapter, term()}}` for invalid adapters.

  """
  @spec get_positions([atom(), ...], DateTime.t(), adapter()) ::
          {:ok, %{atom() => Body.t() | Point.t()}} | {:error, term()}
  def get_positions(bodies, datetime, adapter), do: get_positions(bodies, datetime, adapter, nil)

  @spec get_positions([atom(), ...], DateTime.t(), adapter(), Angelus.Observer.t() | nil) ::
          {:ok, %{atom() => Body.t() | Point.t()}} | {:error, term()}
  def get_positions(bodies, datetime, adapter, observer) do
    with {:ok, adapter} <- validate_adapter(adapter, 3),
         :ok <- validate_datetime(datetime),
         :ok <- validate_body_list_shape(bodies),
         :ok <- validate_duplicates(bodies),
         :ok <- validate_public_range(datetime) do
      build_positions(bodies, datetime, adapter, observer)
    end
  end

  defp build_positions(bodies, datetime, adapter, observer) do
    Enum.reduce_while(bodies, {:ok, %{}}, fn body, {:ok, acc} ->
      case adapter.get_position(datetime, body, observer) do
        {:ok, position} -> {:cont, {:ok, Map.put(acc, body, position)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_adapter(adapter, arity) do
    if valid_adapter?(adapter, arity),
      do: {:ok, adapter},
      else: {:error, {:invalid_adapter, adapter}}
  end

  defp valid_adapter?(adapter, arity) when is_atom(adapter) do
    Code.ensure_loaded?(adapter) and function_exported?(adapter, :get_position, arity)
  end

  defp valid_adapter?(_adapter, _arity), do: false

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
