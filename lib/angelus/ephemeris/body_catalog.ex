defmodule Angelus.Ephemeris.BodyCatalog.Target do
  @moduledoc "Struct representing a SPICE target body and its associated metadata."

  defstruct [
    :spice_target,
    :spice_id,
    :target_kind,
    :required_spk,
    :calculation
  ]

  @type t :: %__MODULE__{
          spice_target: String.t() | nil,
          spice_id: integer() | nil,
          target_kind: atom(),
          required_spk: String.t() | nil,
          calculation: atom() | nil
        }
end

defmodule Angelus.Ephemeris.BodyCatalog do
  @moduledoc "Canonical v0.1 ephemeris body catalog and SPICE target metadata."

  alias Angelus.Ephemeris.BodyCatalog.Target

  @targets %{
    sun: %Target{spice_target: "SUN", spice_id: 10, target_kind: :body_center},
    moon: %Target{spice_target: "MOON", spice_id: 301, target_kind: :body_center},
    mercury: %Target{spice_target: "MERCURY", spice_id: 199, target_kind: :body_center},
    venus: %Target{spice_target: "VENUS", spice_id: 299, target_kind: :body_center},
    mars: %Target{
      spice_target: "MARS",
      spice_id: 499,
      target_kind: :body_center,
      required_spk: "mar099.bsp"
    },
    jupiter: %Target{
      spice_target: "JUPITER",
      spice_id: 599,
      target_kind: :body_center,
      required_spk: "jup349.bsp"
    },
    saturn: %Target{
      spice_target: "SATURN",
      spice_id: 699,
      target_kind: :body_center,
      required_spk: "sat459.bsp"
    },
    uranus: %Target{
      spice_target: "URANUS",
      spice_id: 799,
      target_kind: :body_center,
      required_spk: "ura184_part-1.bsp"
    },
    neptune: %Target{
      spice_target: "NEPTUNE",
      spice_id: 899,
      target_kind: :body_center,
      required_spk: "nep105.bsp"
    },
    pluto: %Target{
      spice_target: "PLUTO",
      spice_id: 999,
      target_kind: :body_center,
      required_spk: "plu060.bsp"
    },
    true_node: %Target{
      target_kind: :lunar_node,
      calculation: :true_lunar_node
    },
    mean_node: %Target{
      target_kind: :lunar_node,
      calculation: :mean_lunar_node
    },
    chiron: %Target{
      spice_target: "CHIRON",
      spice_id: 2_060,
      target_kind: :minor_planet,
      calculation: :spice_body_center
    },
    lilith: %Target{
      target_kind: :lunar_apogee,
      calculation: :mean_lunar_apogee
    }
  }

  @doc "Returns all public body atoms supported by the v0.1 ephemeris API."
  @spec supported_bodies() :: [atom()]
  def supported_bodies, do: Map.keys(@targets)

  @doc "Fetches catalog metadata for a public ephemeris body atom."
  @spec fetch(atom()) :: {:ok, Target.t()} | {:error, {:unsupported_body, atom()}}
  def fetch(body) when is_atom(body) do
    case Map.fetch(@targets, body) do
      {:ok, target} -> {:ok, target}
      :error -> {:error, {:unsupported_body, body}}
    end
  end
end
