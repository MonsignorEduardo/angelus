defmodule Angelus.Ephemeris.BodyCatalog do
  @moduledoc "Canonical v0.1 ephemeris body catalog and SPICE target metadata."

  @targets %{
    sun: %{spice_target: "SUN", spice_id: 10, target_kind: :body_center},
    moon: %{spice_target: "MOON", spice_id: 301, target_kind: :body_center},
    mercury: %{spice_target: "MERCURY", spice_id: 199, target_kind: :body_center},
    venus: %{spice_target: "VENUS", spice_id: 299, target_kind: :body_center},
    mars: %{
      spice_target: "MARS",
      spice_id: 499,
      target_kind: :body_center,
      required_spk: "mar099.bsp"
    },
    jupiter: %{
      spice_target: "JUPITER",
      spice_id: 599,
      target_kind: :body_center,
      required_spk: "jup349.bsp"
    },
    saturn: %{
      spice_target: "SATURN",
      spice_id: 699,
      target_kind: :body_center,
      required_spk: "sat459.bsp"
    },
    uranus: %{
      spice_target: "URANUS",
      spice_id: 799,
      target_kind: :body_center,
      required_spk: "ura184_part-1.bsp"
    },
    neptune: %{
      spice_target: "NEPTUNE",
      spice_id: 899,
      target_kind: :body_center,
      required_spk: "nep105.bsp"
    },
    pluto: %{
      spice_target: "PLUTO",
      spice_id: 999,
      target_kind: :body_center,
      required_spk: "plu060.bsp"
    },
    true_node: %{
      target_kind: :lunar_node,
      calculation: :true_lunar_node
    },
    mean_node: %{
      target_kind: :lunar_node,
      calculation: :mean_lunar_node
    },
    chiron: %{
      spice_target: "CHIRON",
      spice_id: 2_060,
      target_kind: :minor_planet,
      calculation: :spice_body_center
    },
    lilith: %{
      target_kind: :lunar_apogee,
      calculation: :mean_lunar_apogee
    }
  }

  @doc "Returns all public body atoms supported by the v0.1 ephemeris API."
  @spec supported_bodies() :: [atom()]
  def supported_bodies, do: Map.keys(@targets)

  @doc "Fetches catalog metadata for a public ephemeris body atom."
  @spec fetch(atom()) :: {:ok, map()} | {:error, {:unsupported_body, atom()}}
  @spec fetch(term()) :: {:error, {:unsupported_body, term()}}
  def fetch(body) when is_atom(body) do
    case Map.fetch(@targets, body) do
      {:ok, target} -> {:ok, target}
      :error -> {:error, {:unsupported_body, body}}
    end
  end

  def fetch(body), do: {:error, {:unsupported_body, body}}
end
