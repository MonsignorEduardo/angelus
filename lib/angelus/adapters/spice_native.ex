defmodule Angelus.Adapters.SpiceNative do
  @moduledoc "Native CSPICE adapter for `Angelus.Ephemeris`."

  @behaviour Angelus.Ephemeris.Adapter

  @impl true
  def utc_to_et(%DateTime{} = datetime), do: Angelus.Spice.utc_to_et(datetime)

  @impl true
  def state(body, et), do: Angelus.Spice.state(body, et)
end
