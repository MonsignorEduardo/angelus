defmodule Angelus.MixProject do
  use Mix.Project

  @app :angelus
  @version "0.1.0"
  @github_url "https://github.com/angelus-astro/angelus"
  @priv_paths ["spice_worker"]
  @cc_precompiler_compilers %{
    {:unix, :darwin} => %{include_default_ones: true},
    {:unix, :linux} => %{include_default_ones: true}
  }

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
      make_precompiler_url: "#{@github_url}/releases/download/v#{@version}/@{artefact_filename}",
      make_precompiler_filename: "spice_worker",
      make_precompiler_priv_paths: @priv_paths,
      cc_precompiler: cc_precompiler(),
      make_cwd: "native/spice_worker",
      make_clean: ["clean"],
      make_force_build: Mix.env() in [:dev, :test],
      dialyzer: dialyzer(),
      package: package()
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
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:nimble_pool, "~> 1.1"},
      {:elixir_make, "~> 0.9", runtime: false},
      {:cc_precompiler, "~> 0.1", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp cc_precompiler do
    [
      only_listed_targets: true,
      compilers: @cc_precompiler_compilers
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
      files: [
        "lib",
        "native/spice_worker",
        "priv/.gitkeep",
        "checksum-angelus.exs",
        "mix.exs",
        "README.md",
        "LICENSE"
      ],
      licenses: ["MIT"],
      links: %{"GitHub" => @github_url}
    ]
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
