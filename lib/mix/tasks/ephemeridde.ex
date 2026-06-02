defmodule Mix.Tasks.Angelus.Ephemeridde do
  @moduledoc "Generates a geocentric ephemeris for a UTC datetime."

  use Mix.Task

  @bodies [
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

  @doc "Generates an ephemeris for all supported bodies at the given UTC datetime."
  @impl true
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    datetime = parse_args!(args)
    Logger.configure(level: :debug)

    Logger.configure_backend(:console,
      format: "$time $metadata[$level] $message\n",
      metadata: :all
    )

    Mix.shell().info("Starting Angelus app...")
    Mix.Task.run("app.start")

    Mix.shell().info("Loading SPICE kernels...")

    with {:ok, _metadata} <- Angelus.load_kernels(replace: true),
         _ <- Mix.shell().info("Computing ephemeris for #{length(@bodies)} bodies..."),
         {:ok, positions} <- Angelus.positions(@bodies, datetime) do
      print_positions(datetime, positions)
    else
      {:error, {:kernel_file_missing, path}} ->
        Mix.raise("missing kernel file #{path}. Run `mix angelus.kernels` first.")

      {:error, {:invalid_kernel_set, reason}} ->
        Mix.raise("could not load kernels: #{inspect(reason)}. Run `mix angelus.kernels` first.")

      {:error, :worker_not_available} ->
        Mix.raise("SPICE worker is not available. Run `mix compile` first.")

      {:error, reason} ->
        Mix.raise("could not generate ephemeris: #{inspect(reason)}")
    end
  end

  defp parse_args!([datetime]) do
    datetime
    |> normalize_datetime()
    |> DateTime.from_iso8601()
    |> case do
      {:ok, parsed, 0} -> parsed
      {:ok, _parsed, _offset} -> Mix.raise("datetime must be UTC and end with Z")
      {:error, _reason} -> usage!()
    end
  end

  defp parse_args!([date, time]), do: parse_args!([date <> " " <> time])

  defp parse_args!(_args), do: usage!()

  defp normalize_datetime(datetime) do
    String.replace(datetime, " ", "T", global: false)
  end

  defp print_positions(datetime, positions) do
    Mix.shell().info("Ephemeris for #{DateTime.to_iso8601(datetime)}")
    Mix.shell().info("")
    Mix.shell().info("body,longitude_deg,latitude_deg,distance_au")

    Enum.each(@bodies, fn body ->
      position = Map.fetch!(positions, body)

      [
        body,
        position.longitude,
        position.latitude,
        position.distance_au
      ]
      |> Enum.join(",")
      |> Mix.shell().info()
    end)
  end

  @spec usage!() :: no_return()
  defp usage! do
    Mix.raise(
      "usage: mix angelus.ephemeridde DATETIME_UTC, for example: mix angelus.ephemeridde 1998-07-18T05:00:00Z"
    )
  end

  @shortdoc "Generates an ephemeris for a UTC datetime"
end
