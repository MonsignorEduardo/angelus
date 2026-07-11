defmodule Angelus.Astro.Catalog.Target do
  @moduledoc "Struct representing a SPICE target body and its associated metadata."

  defstruct [
    :spice_target,
    :spice_id,
    :target_kind
  ]

  @type t :: %__MODULE__{
          spice_target: String.t() | nil,
          spice_id: integer() | nil,
          target_kind: atom()
        }
end

defmodule Angelus.Astro.Catalog do
  @moduledoc "Canonical v0.1 ephemeris body catalog and kernel metadata."

  alias Angelus.Astro.Catalog.Target

  @supported_bodies [
    :sun,
    :moon,
    :mercury,
    :venus,
    :mars,
    :jupiter,
    :saturn,
    :uranus,
    :neptune,
    :pluto,
    :true_node,
    :lilith,
    :chiron,
    :ceres,
    :pallas,
    :juno,
    :vesta,
    :eris
  ]

  @bodies %{
    sun: %{spice_target: "SUN", spice_id: 10, target_kind: :body_center},
    moon: %{spice_target: "MOON", spice_id: 301, target_kind: :body_center},
    mercury: %{spice_target: "MERCURY", spice_id: 199, target_kind: :body_center},
    venus: %{spice_target: "VENUS", spice_id: 299, target_kind: :body_center},
    mars: %{spice_target: "MARS", spice_id: 499, target_kind: :body_center},
    jupiter: %{spice_target: "JUPITER", spice_id: 599, target_kind: :body_center},
    saturn: %{spice_target: "SATURN", spice_id: 699, target_kind: :body_center},
    uranus: %{spice_target: "URANUS", spice_id: 799, target_kind: :body_center},
    neptune: %{spice_target: "NEPTUNE", spice_id: 899, target_kind: :body_center},
    pluto: %{spice_target: "PLUTO", spice_id: 999, target_kind: :body_center},
    true_node: %{
      spice_target: "TRUE_NODE",
      target_kind: :lunar_node
    },
    lilith: %{
      spice_target: "LILITH",
      target_kind: :lunar_apogee
    },
    chiron: %{
      spice_target: "2002060",
      spice_id: 2_002_060,
      target_kind: :minor_planet
    },
    ceres: %{
      spice_target: "2000001",
      spice_id: 2_000_001,
      target_kind: :minor_planet
    },
    pallas: %{
      spice_target: "2000002",
      spice_id: 2_000_002,
      target_kind: :minor_planet
    },
    juno: %{
      spice_target: "2000003",
      spice_id: 2_000_003,
      target_kind: :minor_planet
    },
    vesta: %{
      spice_target: "2000004",
      spice_id: 2_000_004,
      target_kind: :minor_planet
    },
    eris: %{
      spice_target: "2136199",
      spice_id: 2_136_199,
      target_kind: :minor_planet
    }
  }

  @kernels [
    %{
      file: "naif0012.tls",
      type: :lsk,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/naif0012.tls"
      }
    },
    %{
      file: "pck00011.tpc",
      type: :pck,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc"
      }
    },
    %{
      file: "gm_de440.tpc",
      type: :pck,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/gm_de440.tpc"
      }
    },
    %{
      file: "de442.bsp",
      type: :spk,
      ephemeris: :de442,
      policy: :default_modern,
      range: {~D[1549-12-31], ~D[2650-01-25]},
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de442.bsp"
      }
    },
    %{
      file: "mar099.bsp",
      type: :spk,
      role: :body_center_chain,
      target: "MARS",
      spice_id: 499,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/mar099.bsp"
      }
    },
    %{
      file: "jup349.bsp",
      type: :spk,
      role: :body_center_chain,
      target: "JUPITER",
      spice_id: 599,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/jup349.bsp"
      }
    },
    %{
      file: "sat459.bsp",
      type: :spk,
      role: :body_center_chain,
      target: "SATURN",
      spice_id: 699,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/sat459.bsp"
      }
    },
    %{
      file: "ura184_part-1.bsp",
      type: :spk,
      role: :body_center_chain,
      target: "URANUS",
      spice_id: 799,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-1.bsp"
      }
    },
    %{
      file: "ura184_part-2.bsp",
      type: :spk,
      role: :body_center_chain,
      target: "URANUS",
      spice_id: 799,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-2.bsp"
      }
    },
    %{
      file: "ura184_part-3.bsp",
      type: :spk,
      role: :body_center_chain,
      target: "URANUS",
      spice_id: 799,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-3.bsp"
      }
    },
    %{
      file: "nep105.bsp",
      type: :spk,
      role: :body_center_chain,
      target: "NEPTUNE",
      spice_id: 899,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/nep105.bsp"
      }
    },
    %{
      file: "plu060.bsp",
      type: :spk,
      role: :body_center_chain,
      target: "PLUTO",
      spice_id: 999,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/plu060.bsp"
      }
    },
    %{
      file: "2002060.bsp",
      type: :spk,
      role: :minor_planet,
      target: "CHIRON",
      spice_id: 2_002_060,
      source: %{
        kind: :url,
        url:
          "https://github.com/MonsignorEduardo/angelus/releases/download/kernels-v0.1/2002060.bsp",
        sha256: "fc3b00dc8844b443e21b647dca3c42641ba5fe45679526c783365103f5ab8e74"
      }
    },
    %{
      file: "2000001.bsp",
      type: :spk,
      role: :minor_planet,
      target: "CERES",
      spice_id: 2_000_001,
      source: %{
        kind: :url,
        url:
          "https://github.com/MonsignorEduardo/angelus/releases/download/kernels-v0.1/2000001.bsp",
        sha256: "0e995be446f281632b3101f9e86807bf6bba6839b79f9cf1265495839b6552b3"
      }
    },
    %{
      file: "2000002.bsp",
      type: :spk,
      role: :minor_planet,
      target: "PALLAS",
      spice_id: 2_000_002,
      source: %{
        kind: :url,
        url:
          "https://github.com/MonsignorEduardo/angelus/releases/download/kernels-v0.1/2000002.bsp",
        sha256: "70d503ccb9fcb95af4fb9f1e68347ca24f6457c60851dbae2a178a99b86133d8"
      }
    },
    %{
      file: "2000003.bsp",
      type: :spk,
      role: :minor_planet,
      target: "JUNO",
      spice_id: 2_000_003,
      source: %{
        kind: :url,
        url:
          "https://github.com/MonsignorEduardo/angelus/releases/download/kernels-v0.1/2000003.bsp",
        sha256: "c8d5a694bf4f8fc8dbc7ef5ef1a1a88849eb10b392a19a280ea8526441e544e1"
      }
    },
    %{
      file: "2000004.bsp",
      type: :spk,
      role: :minor_planet,
      target: "VESTA",
      spice_id: 2_000_004,
      source: %{
        kind: :url,
        url:
          "https://github.com/MonsignorEduardo/angelus/releases/download/kernels-v0.1/2000004.bsp",
        sha256: "6638f94e727dfa4fdb757099df11fdf6763b0aa967123033383f53078ec07110"
      }
    },
    %{
      file: "2136199.bsp",
      type: :spk,
      role: :minor_planet,
      target: "ERIS",
      spice_id: 2_136_199,
      source: %{
        kind: :url,
        url:
          "https://github.com/MonsignorEduardo/angelus/releases/download/kernels-v0.1/2136199.bsp",
        sha256: "2d03e6c7e5b93d3b4a39619fa55fa9c2acc0ea5e4ed5975aafb8aa08d0226563"
      }
    }
  ]

  @doc "Returns all public body atoms supported by the v0.1 ephemeris API."
  @spec supported_bodies() :: [atom()]
  def supported_bodies, do: @supported_bodies

  @doc "Returns the complete public target catalog keyed by body atom."
  @spec get_catalog() :: %{atom() => Target.t()}
  def get_catalog, do: Map.new(@bodies, fn {body, attrs} -> {body, struct(Target, attrs)} end)

  @doc "Fetches catalog metadata for a public ephemeris body atom."
  @spec get_metadata(atom()) :: {:ok, Target.t()} | {:error, {:unsupported_body, atom()}}
  def get_metadata(body) when is_atom(body) do
    case Map.fetch(@bodies, body) do
      {:ok, attrs} -> {:ok, struct(Target, attrs)}
      :error -> {:error, {:unsupported_body, body}}
    end
  end

  @doc "Returns the complete configured kernel list in load order."
  @spec get_kernel() :: [map()]
  def get_kernel, do: @kernels
end
