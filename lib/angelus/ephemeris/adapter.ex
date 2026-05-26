defmodule Angelus.Ephemeris.Adapter do
  @moduledoc """
  Contract for ephemeris engines used by `Angelus.Ephemeris`.

  Adapters return SPICE-like state maps; `Angelus.Ephemeris` owns validation,
  longitude normalization, and public `%Angelus.Ephemeris.BodyPosition{}` construction.
  """

  @callback utc_to_et(DateTime.t()) :: {:ok, float()} | {:error, term()}
  @callback state(atom(), float()) :: {:ok, map()} | {:error, term()}
end
