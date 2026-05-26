defmodule Angelus do
  @moduledoc """
  High-level geocentric ephemeris API backed by SPICE/JPL.

  ## Quick start

      # 1. Download kernels (once)
      mix angelus.kernels

      # 2. Load kernels at runtime
      :ok = Angelus.load_kernels()

      # 3. Query positions
      {:ok, positions} = Angelus.positions(
        [:sun, :moon, :mercury, :venus, :mars,
         :jupiter, :saturn, :uranus, :neptune, :pluto],
        ~U[1990-05-24 06:30:00Z]
      )

  See `Angelus.Ephemeris` and `Angelus.Spice` for the full API.
  """

  @version Mix.Project.config()[:version]

  @doc "Returns the Angelus library version."
  @spec version() :: String.t()
  def version, do: @version

  # ── Re-exported API ──────────────────────────────────────────────────────

  @doc """
  Returns the geocentric position of a single body at the given UTC datetime.

  Delegates to `Angelus.Ephemeris.position/3`.
  """
  defdelegate position(body, datetime, opts \\ []), to: Angelus.Ephemeris

  @doc """
  Returns the geocentric positions of a list of bodies at the given UTC datetime.

  Delegates to `Angelus.Ephemeris.positions/3`.
  """
  defdelegate positions(bodies, datetime, opts \\ []), to: Angelus.Ephemeris

  @doc """
  Loads the default v0.1 SPICE kernel set from `priv/kernels/`.

  Delegates to `Angelus.Spice.load_kernels/0`.
  """
  defdelegate load_kernels(), to: Angelus.Spice

  @doc """
  Loads SPICE kernels with options or explicit paths.

  Delegates to `Angelus.Spice.load_kernels/1`.
  """
  defdelegate load_kernels(paths_or_opts), to: Angelus.Spice
end
