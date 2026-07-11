defmodule Angelus do
  @moduledoc """
  High-level geocentric ephemeris API backed by SPICE/JPL.

  ## Quick start

      # 1. Download kernels (once)
      mix angelus.kernels

      # 2. Load kernels at runtime
      {:ok, adapter} = Angelus.load_kernels()

      # 3. Query positions
      {:ok, positions} = Angelus.get_positions(
        [:sun, :moon, :mercury, :venus, :mars,
         :jupiter, :saturn, :uranus, :neptune, :pluto,
         :true_node, :lilith, :chiron, :ceres, :pallas,
         :juno, :vesta, :eris],
        ~U[1990-05-24 06:30:00Z],
        adapter
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

  This is a convenience wrapper around `get_positions/3`.
  """
  @spec get_position(atom(), DateTime.t(), Angelus.Astro.adapter()) ::
          {:ok, Angelus.Astro.Body.t() | Angelus.Astro.Point.t()} | {:error, term()}
  def get_position(body, datetime, adapter)

  def get_position(body, datetime, adapter) when is_atom(body) do
    with {:ok, positions} <- get_positions([body], datetime, adapter) do
      {:ok, Map.fetch!(positions, body)}
    end
  end

  def get_position(_body, _datetime, _adapter), do: {:error, :invalid_body}

  @doc """
  Returns the geocentric positions of a list of bodies at the given UTC datetime.

  Delegates to `Angelus.Astro.get_positions/3`.
  """
  @spec get_positions([atom(), ...], DateTime.t(), Angelus.Astro.adapter()) ::
          {:ok, %{atom() => Angelus.Astro.Body.t() | Angelus.Astro.Point.t()}}
          | {:error, term()}
  defdelegate get_positions(bodies, datetime, adapter), to: Angelus.Astro

  @doc """
  Returns topocentric positions for a list of bodies at the given UTC datetime.

  `coordinates` must be `{latitude_degrees, longitude_degrees, altitude_meters}`.

  Delegates to `Angelus.Astro.get_positions/4`.
  """
  @spec get_positions(
          [atom(), ...],
          DateTime.t(),
          Angelus.Astro.coordinates(),
          Angelus.Astro.adapter()
        ) ::
          {:ok, %{atom() => Angelus.Astro.Body.t() | Angelus.Astro.Point.t()}}
          | {:error, term()}
  defdelegate get_positions(bodies, datetime, coordinates, adapter), to: Angelus.Astro

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
