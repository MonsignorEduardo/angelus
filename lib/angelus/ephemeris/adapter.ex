defmodule Angelus.Ephemeris.Adapter do
  @moduledoc """
  Contract for ephemeris engines used by `Angelus.Ephemeris`.

  Adapters are expected to implement a single entrypoint `get_ephemeride/3`
  which performs the full UTC -> ET -> state pipeline in one round-trip.
  The native motor performs any unit conversions (degrees vs radians).
  """

  @type opt :: :rad | :angles

  @callback get_ephemeride(DateTime.t(), atom(), [opt]) ::
              {:ok, Angelus.Ephemeris.BodyPosition.t()} | {:error, term()}
end
