defmodule Angelus.MixProject do
  use Mix.Project

  @app :angelus
  @version "0.0.2"
  @source_url "https://github.com/MonsignorEduardo/angelus"
  @priv_paths ["spice_worker"]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      make_precompiler: {:port, CCPrecompiler},
      make_precompiler_url: "#{@source_url}/releases/download/v#{@version}/@{artefact_filename}",
      make_precompiler_filename: "spice_worker",
      make_precompiler_priv_paths: @priv_paths,
      cc_precompiler: cc_precompiler(),
      make_cwd: "native/spice_worker",
      make_force_build: System.get_env("ANGELUS_FORCE_BUILD") == "1",
      dialyzer: dialyzer(),
      description: description(),
      package: package(),
      name: "Angelus",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Angelus.Application, []}
    ]
  end

  defp deps do
    [
      {:cc_precompiler, "~> 0.1", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:elixir_make, "~> 0.9", runtime: false},
      {:ex_doc, "~> 0.40.3", only: :dev, runtime: false, warn_if_outdated: true},
      {:jason, "~> 1.4"},
      {:nimble_pool, "~> 1.1"},
      {:req, "~> 0.5"}
    ]
  end

  defp cc_precompiler do
    [
      only_listed_targets: true,
      compilers: %{
        {:unix, :darwin} => %{
          "aarch64-apple-darwin" =>
            {"gcc", "g++", "<%= cc %> -arch arm64", "<%= cxx %> -arch arm64"}
        },
        {:unix, :linux} => %{"x86_64-linux-gnu" => "x86_64-linux-gnu-"}
      }
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      plt_local_path: "priv/plts"
    ]
  end

  defp package do
    [
      maintainers: ["Eduardo Gonzalez"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: [
        "lib",
        "native/spice_worker/Makefile",
        "native/spice_worker/fetch-libs.sh",
        "native/spice_worker/patches",
        "native/spice_worker/src",
        "priv/.gitkeep",
        "checksum.exs",
        "mix.exs",
        "README.md",
        "BUILDING.md",
        "THIRD_PARTY_NOTICES.md",
        "LICENSE"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "THIRD_PARTY_NOTICES.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Guides: ["README.md"],
        Legal: ["THIRD_PARTY_NOTICES.md", "LICENSE"]
      ]
    ]
  end

  defp description do
    """
    Elixir ephemeris library backed by NAIF CSPICE and JPL kernels.
    """
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp aliases do
    [
      setup: ["deps.get"],
      consistency: [
        "cmd echo Checking format ...",
        "format",
        "cmd echo",
        "cmd echo Checking compile warnings ...",
        "compile --no-deps-check --force",
        "cmd echo",
        "cmd echo Checking Credo ...",
        "credo -A",
        "cmd echo",
        "cmd echo Checking tests ...",
        "cmd sh -c 'MIX_ENV=test mix test'",
        "cmd echo"
      ]
    ]
  end
end
