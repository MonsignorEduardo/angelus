defmodule Angelus.Ephemeris.BodyCatalog.Target do
  @moduledoc "Struct representing a SPICE target body and its associated metadata."

  defstruct [
    :spice_target,
    :spice_id,
    :target_kind,
    :calculation
  ]

  @type t :: %__MODULE__{
          spice_target: String.t() | nil,
          spice_id: integer() | nil,
          target_kind: atom(),
          calculation: atom() | nil
        }
end

defmodule Angelus.Ephemeris.BodyCatalog do
  @moduledoc "Canonical v0.1 ephemeris body catalog and kernel metadata."

  alias Angelus.Ephemeris.BodyCatalog.Target

  @type source :: %{kind: :url, url: String.t()} | %{kind: :bundled, path: String.t()}

  @ephemeris :de442
  @kernel_policy :default
  @public_range %{from: ~D[1900-01-01], to: ~D[2100-01-24]}

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
      target_kind: :lunar_node,
      calculation: :true_lunar_node
    },
    lilith: %{
      spice_target: "LILITH",
      target_kind: :lunar_apogee,
      calculation: :mean_lunar_apogee
    },
    chiron: %{
      spice_target: "20002060",
      spice_id: 20_002_060,
      target_kind: :minor_planet,
      calculation: :spice_body_center
    },
    ceres: %{
      spice_target: "20000001",
      spice_id: 20_000_001,
      target_kind: :minor_planet,
      calculation: :spice_body_center
    },
    pallas: %{
      spice_target: "20000002",
      spice_id: 20_000_002,
      target_kind: :minor_planet,
      calculation: :spice_body_center
    },
    juno: %{
      spice_target: "20000003",
      spice_id: 20_000_003,
      target_kind: :minor_planet,
      calculation: :spice_body_center
    },
    vesta: %{
      spice_target: "20000004",
      spice_id: 20_000_004,
      target_kind: :minor_planet,
      calculation: :spice_body_center
    },
    eris: %{
      spice_target: "20136199",
      spice_id: 20_136_199,
      target_kind: :minor_planet,
      calculation: :spice_body_center
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
      file: "20002060.bsp",
      type: :spk,
      role: :minor_planet,
      target: "CHIRON",
      spice_id: 20_002_060,
      source: %{kind: :bundled, path: Path.expand("native/src/kernels/20002060.bsp", File.cwd!())}
    },
    %{
      file: "20000001.bsp",
      type: :spk,
      role: :minor_planet,
      target: "CERES",
      spice_id: 20_000_001,
      source: %{kind: :bundled, path: Path.expand("native/src/kernels/20000001.bsp", File.cwd!())}
    },
    %{
      file: "20000002.bsp",
      type: :spk,
      role: :minor_planet,
      target: "PALLAS",
      spice_id: 20_000_002,
      source: %{kind: :bundled, path: Path.expand("native/src/kernels/20000002.bsp", File.cwd!())}
    },
    %{
      file: "20000003.bsp",
      type: :spk,
      role: :minor_planet,
      target: "JUNO",
      spice_id: 20_000_003,
      source: %{kind: :bundled, path: Path.expand("native/src/kernels/20000003.bsp", File.cwd!())}
    },
    %{
      file: "20000004.bsp",
      type: :spk,
      role: :minor_planet,
      target: "VESTA",
      spice_id: 20_000_004,
      source: %{kind: :bundled, path: Path.expand("native/src/kernels/20000004.bsp", File.cwd!())}
    },
    %{
      file: "20136199.bsp",
      type: :spk,
      role: :minor_planet,
      target: "ERIS",
      spice_id: 20_136_199,
      source: %{kind: :bundled, path: Path.expand("native/src/kernels/20136199.bsp", File.cwd!())}
    }
  ]

  @doc "Returns all public body atoms supported by the v0.1 ephemeris API."
  @spec supported_bodies() :: [atom()]
  def supported_bodies, do: @supported_bodies

  @doc "Fetches catalog metadata for a public ephemeris body atom."
  @spec fetch(atom()) :: {:ok, Target.t()} | {:error, {:unsupported_body, atom()}}
  def fetch(body) when is_atom(body) do
    case Map.fetch(@bodies, body) do
      {:ok, attrs} -> {:ok, struct(Target, attrs)}
      :error -> {:error, {:unsupported_body, body}}
    end
  end

  @doc "Returns all required kernel filenames in load order."
  @spec required_files() :: [String.t()]
  def required_files, do: Enum.map(kernels(), & &1.file)

  @doc "Returns required leap-seconds kernel filenames."
  @spec lsks() :: [String.t()]
  def lsks, do: files_by_type(:lsk)

  @doc "Returns required text planetary-constants kernel filenames."
  @spec tpcs() :: [String.t()]
  def tpcs, do: files_by_type(:pck)

  @doc "Returns required SPK kernel filenames."
  @spec spks() :: [String.t()]
  def spks, do: files_by_type(:spk)

  @doc "Builds absolute kernel paths under `base_path`."
  @spec default_paths(String.t()) :: [String.t()]
  def default_paths(base_path) when is_binary(base_path),
    do: Enum.map(required_files(), &Path.join(base_path, &1))

  @doc "Returns normalized metadata for all configured kernels."
  @spec kernels() :: [map()]
  def kernels, do: @kernels

  @doc "Returns configured kernel download/copy sources keyed by filename."
  @spec sources() :: %{String.t() => source()}
  def sources, do: Map.new(kernels(), &{&1.file, &1.source})

  @doc "Builds metadata for a validated kernel path list."
  @spec metadata([String.t()]) :: map()
  def metadata(paths) do
    by_file = Map.new(paths, fn path -> {Path.basename(path), path} end)

    %{
      ephemeris: @ephemeris,
      kernel_policy: @kernel_policy,
      public_range: @public_range,
      kernels: Enum.map(kernels(), &kernel_metadata(&1, Map.fetch!(by_file, &1.file)))
    }
  end

  defp files_by_type(type) do
    kernels()
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(& &1.file)
  end

  defp kernel_metadata(kernel, path) do
    kernel
    |> Map.drop([:source])
    |> Map.put(:path, path)
  end
end
