defmodule Angelus.Astro.Catalog.Target do
  @moduledoc false
  defstruct [:spice_target, :spice_id, :target_kind]

  @type t :: %__MODULE__{
          spice_target: String.t() | nil,
          spice_id: integer() | nil,
          target_kind: atom()
        }
end

defmodule Angelus.Astro.Catalog do
  @moduledoc false

  alias Angelus.Astro.Catalog.Target

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
    true_node: %{spice_target: "TRUE_NODE", target_kind: :lunar_node},
    lilith: %{spice_target: "LILITH", target_kind: :lunar_apogee},
    chiron: %{spice_target: "20002060", spice_id: 20_002_060, target_kind: :minor_planet}
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
      file: "earth_1962_250826_2125_combined.bpc",
      type: :pck,
      role: :earth_orientation,
      source: %{
        kind: :url,
        url:
          "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/earth_1962_250826_2125_combined.bpc",
        sha256: "4d2419db5f734a5af95b4a35a6b81cf2b281ffb18d0a849f217a33e930e2229d"
      }
    },
    %{
      file: "de442.bsp",
      type: :spk,
      ephemeris: :de442,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de442.bsp"
      }
    },
    %{
      file: "mar099.bsp",
      type: :spk,
      role: :body_center_chain,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/mar099.bsp"
      }
    },
    %{
      file: "jup349.bsp",
      type: :spk,
      role: :body_center_chain,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/jup349.bsp"
      }
    },
    %{
      file: "sat459.bsp",
      type: :spk,
      role: :body_center_chain,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/sat459.bsp"
      }
    },
    %{
      file: "ura184_part-1.bsp",
      type: :spk,
      role: :body_center_chain,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-1.bsp"
      }
    },
    %{
      file: "ura184_part-2.bsp",
      type: :spk,
      role: :body_center_chain,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-2.bsp"
      }
    },
    %{
      file: "ura184_part-3.bsp",
      type: :spk,
      role: :body_center_chain,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/ura184_part-3.bsp"
      }
    },
    %{
      file: "nep105.bsp",
      type: :spk,
      role: :body_center_chain,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/nep105.bsp"
      }
    },
    %{
      file: "plu060.bsp",
      type: :spk,
      role: :body_center_chain,
      source: %{
        kind: :url,
        url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/plu060.bsp"
      }
    },
    %{
      file: "2002060.bsp",
      type: :spk,
      role: :minor_planet,
      source: %{
        kind: :url,
        url:
          "https://github.com/MonsignorEduardo/angelus/releases/download/kernels-v0.2/2002060.bsp",
        sha256: "fc3b00dc8844b443e21b647dca3c42641ba5fe45679526c783365103f5ab8e74"
      }
    }
  ]

  @spec get_metadata(atom()) :: {:ok, Target.t()} | {:error, {:unsupported_body, atom()}}
  def get_metadata(body) when is_atom(body) do
    case Map.fetch(@bodies, body) do
      {:ok, attrs} -> {:ok, struct(Target, attrs)}
      :error -> {:error, {:unsupported_body, body}}
    end
  end

  @spec get_kernel() :: [map()]
  def get_kernel, do: @kernels
end
