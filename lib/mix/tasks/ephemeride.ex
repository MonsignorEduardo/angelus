defmodule Mix.Tasks.Angelus.Ephemeride do
  @moduledoc "Prints an Angelus ephemeris for one ISO 8601 instant."

  use Mix.Task

  @names %{
    sun: "Sun",
    moon: "Moon",
    mercury: "Mercury",
    venus: "Venus",
    mars: "Mars",
    jupiter: "Jupiter",
    saturn: "Saturn",
    uranus: "Uranus",
    neptune: "Neptune",
    pluto: "Pluto",
    north_node: "North Node",
    south_node: "South Node",
    lilith: "Lilith",
    chiron: "Chiron"
  }

  @impl true
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    Logger.configure(level: :warning)
    Mix.Task.run("app.start")

    with {options, [datetime], []} <-
           OptionParser.parse(args, strict: [latitude: :float, longitude: :float, height: :float]),
         {:ok, datetime, _offset} <- DateTime.from_iso8601(datetime),
         {:ok, ephemeride_options} <- ephemeride_options(options),
         {:ok, ephemeride} <- Angelus.get_ephemeride(datetime, ephemeride_options) do
      print(ephemeride)
    else
      {_options, _arguments, _invalid} ->
        Mix.raise(usage())

      {:error, :incomplete_observer} ->
        Mix.raise("--latitude, --longitude and --height must be provided together")

      {:error, reason} ->
        Mix.raise("could not calculate ephemeris: #{inspect(reason)}")
    end
  end

  defp print(ephemeride) do
    Mix.shell().info("UTC: #{DateTime.to_iso8601(ephemeride.time.utc)}")
    Mix.shell().info("Schema version: #{ephemeride.schema_version}")
    Mix.shell().info("Time quality: #{ephemeride.time.quality}")

    case ephemeride.reference.observers do
      %{topocentric: observer} ->
        Mix.shell().info(
          "Observer: #{observer.latitude_deg} deg, #{observer.longitude_deg} deg, #{observer.height_m} m"
        )

      _observers ->
        :ok
    end

    Mix.shell().info("")

    (ephemeride.bodies ++ ephemeride.points)
    |> rows()
    |> render_table([
      "Body",
      "Ecl. lon (deg)",
      "Ecliptic lat (deg)",
      "RA (deg)",
      "Declination (deg)",
      "Longitude rate (rad/day)",
      "Distance (AU)",
      "Radial velocity (km/s)"
    ])
    |> Mix.shell().info()
  end

  defp rows(entries) do
    Enum.map(entries, fn entry ->
      solution = Map.get(entry.solutions, :topocentric, entry.solutions.geocentric)

      [
        Map.fetch!(@names, entry.id),
        format_angle(solution.ecliptic.longitude_rad),
        format_angle(solution.ecliptic.latitude_rad),
        format_angle(solution.equatorial.right_ascension_rad),
        format_angle(solution.equatorial.declination_rad),
        format_rate(solution.ecliptic.longitude_rate_rad_day),
        format_number(Map.get(solution, :distance_au)),
        format_number(Map.get(solution, :radial_velocity_km_s))
      ]
    end)
  end

  defp render_table(rows, header) do
    widths =
      [header | rows]
      |> Enum.zip()
      |> Enum.map(fn column ->
        column |> Tuple.to_list() |> Enum.map(&String.length/1) |> Enum.max()
      end)

    separator = "+" <> Enum.map_join(widths, "+", &String.duplicate("-", &1 + 2)) <> "+"

    [separator, render_row(header, widths), separator]
    |> Kernel.++(Enum.map(rows, &render_row(&1, widths)))
    |> Kernel.++([separator])
    |> Enum.join("\n")
  end

  defp render_row(row, widths) do
    "|" <>
      (row
       |> Enum.zip(widths)
       |> Enum.map_join("|", fn {value, width} ->
         " " <> String.pad_trailing(value, width) <> " "
       end)) <> "|"
  end

  defp format_angle(angle),
    do: :erlang.float_to_binary(angle * 180.0 / :math.pi(), decimals: 4) <> "deg"

  defp format_rate(rate), do: :erlang.float_to_binary(rate, decimals: 6)
  defp format_number(nil), do: "-"
  defp format_number(number), do: :erlang.float_to_binary(number, decimals: 6)

  defp ephemeride_options(options) do
    observer = Keyword.take(options, [:latitude, :longitude, :height])

    case observer do
      [] ->
        {:ok, []}

      [latitude: latitude, longitude: longitude, height: height] ->
        {:ok, observer: [latitude_deg: latitude, longitude_deg: longitude, height_m: height]}

      _observer ->
        {:error, :incomplete_observer}
    end
  end

  defp usage do
    "usage: mix angelus.ephemeride DATETIME [--latitude DEG --longitude DEG --height METERS]"
  end

  @shortdoc "Prints an Angelus ephemeris"
end
