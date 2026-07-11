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

    Mix.shell().info("Starting Angelus app...")
    Mix.Task.run("app.start")

    Mix.shell().info("Loading SPICE kernels...")

    with {:ok, adapter} <- Angelus.load_kernels(replace: true),
         _ <- Mix.shell().info("Computing ephemeris for #{length(@bodies)} bodies..."),
         {:ok, positions} <- Angelus.get_positions(@bodies, datetime, adapter) do
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
    Mix.shell().info("Astro positions for #{DateTime.to_iso8601(datetime)}")
    Mix.shell().info("")
    Mix.shell().info("target,position_km,velocity_km_s,distance_au,longitude_rad,speed_rad_day")

    Enum.each(@bodies, fn body ->
      position = Map.fetch!(positions, body)

      position
      |> format_position(body)
      |> Mix.shell().info()
    end)
  end

  defp format_position(%Angelus.Astro.Body{} = position, body) do
    [
      body,
      format_vector(position.position_km),
      format_vector(position.velocity_km_s),
      position.distance_au,
      nil,
      nil
    ]
    |> format_row()
  end

  defp format_position(%Angelus.Astro.Point{} = position, body) do
    [
      body,
      nil,
      nil,
      nil,
      position.longitude_rad,
      position.speed_rad_day
    ]
    |> format_row()
  end

  defp format_row(values) do
    values
    |> Enum.map(&to_string/1)
    |> Enum.join(",")
  end

  defp format_vector({x, y, z}), do: "#{x};#{y};#{z}"

  defp format_vector(nil), do: nil

  @spec usage!() :: no_return()
  defp usage! do
    Mix.raise(
      "usage: mix angelus.ephemeridde DATETIME_UTC, for example: mix angelus.ephemeridde 1998-07-18T05:00:00Z"
    )
  end

  @shortdoc "Generates an ephemeris for a UTC datetime"
end
