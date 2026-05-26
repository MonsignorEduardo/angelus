defmodule Angelus.Adapters.SpiceNative do
  @moduledoc "Native CSPICE adapter for `Angelus.Ephemeris`."

  @behaviour Angelus.Ephemeris.Adapter

  @impl true
  @spec utc_to_et(DateTime.t()) :: {:ok, float()} | {:error, term()}
  def utc_to_et(%DateTime{} = datetime), do: Angelus.Spice.utc_to_et(datetime)

  @impl true
  @spec state(atom(), float()) :: {:ok, map()} | {:error, term()}
  def state(body, et), do: Angelus.Spice.state(body, et)
end
