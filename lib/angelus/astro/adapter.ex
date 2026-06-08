defmodule Angelus.Astro.Adapter do
  @moduledoc """
  Contract for astro engines used by `Angelus.Astro`.

  Adapters resolve supported target atoms and return the public Astro struct for
  that target type.
  """

  alias Angelus.Astro.Body
  alias Angelus.Astro.Point

  @type opt :: term()

  @callback prepare_adapter([opt()]) :: {:ok, module()} | {:error, term()}

  @callback get_ephemeride(DateTime.t(), atom(), keyword(opt)) ::
              {:ok, Body.t() | Point.t()} | {:error, term()}
end
