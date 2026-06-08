defmodule Angelus do
  @moduledoc """
  High-level geocentric ephemeris API backed by SPICE/JPL.

  ## Quick start

      # 1. Download kernels (once)
      mix angelus.kernels

      # 2. Load kernels at runtime
      {:ok, adapter} = Angelus.load_kernels()

      # 3. Query positions
      {:ok, positions} = Angelus.positions(
        [:sun, :moon, :mercury, :venus, :mars,
         :jupiter, :saturn, :uranus, :neptune, :pluto,
         :true_node, :lilith, :chiron, :ceres, :pallas,
         :juno, :vesta, :eris],
        ~U[1990-05-24 06:30:00Z],
        adapter: adapter
      )

  See `Angelus.Astro` and `Angelus.Motor` for the full API.
  """

  @version Mix.Project.config()[:version]

  @doc "Returns the Angelus library version."
  @spec version() :: String.t()
  def version, do: @version

  # ── Re-exported API ──────────────────────────────────────────────────────

  @doc """
  Returns the geocentric position of a single body at the given UTC datetime.

  This is a convenience wrapper around `positions/3`.
  """
  @spec position(atom(), DateTime.t(), Angelus.Astro.options()) ::
          {:ok, Angelus.Astro.Body.t() | Angelus.Astro.Point.t()} | {:error, term()}
  def position(body, datetime, opts \\ [])

  def position(body, datetime, opts) when is_atom(body) do
    with {:ok, positions} <- positions([body], datetime, opts) do
      {:ok, Map.fetch!(positions, body)}
    end
  end

  def position(_body, _datetime, _opts), do: {:error, :invalid_body}

  @doc """
  Returns the geocentric positions of a list of bodies at the given UTC datetime.

  Delegates to `Angelus.Astro.positions/3`.
  """
  @spec positions([atom(), ...], DateTime.t(), Angelus.Astro.options()) ::
          {:ok, %{atom() => Angelus.Astro.Body.t() | Angelus.Astro.Point.t()}}
          | {:error, term()}
  defdelegate positions(bodies, datetime, opts \\ []), to: Angelus.Astro

  @doc """
  Loads the default v0.1 SPICE kernel set from `priv/kernels/` and returns
  the prepared SPICE Astro adapter.

  Use `Angelus.Motor.load_kernels/0` directly when kernel metadata is needed.
  """
  @spec load_kernels() :: {:ok, Angelus.Astro.adapter()} | {:error, term()}
  def load_kernels, do: Angelus.Astro.Adapters.Spice.prepare_adapter()

  @doc """
  Loads SPICE kernels with options or explicit paths and returns the prepared
  SPICE Astro adapter.

  Use `Angelus.Motor.load_kernels/1` directly when kernel metadata is needed.
  """
  @spec load_kernels([Angelus.Motor.load_kernel_option()] | [String.t()]) ::
          {:ok, Angelus.Astro.adapter()} | {:error, term()}
  def load_kernels(paths_or_opts), do: Angelus.Astro.Adapters.Spice.prepare_adapter(paths_or_opts)
end
