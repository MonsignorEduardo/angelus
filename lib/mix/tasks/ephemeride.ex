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
  def run([datetime]) do
    Logger.configure(level: :warning)
    Mix.Task.run("app.start")

    with {:ok, datetime, _offset} <- DateTime.from_iso8601(datetime),
         {:ok, ephemeride} <- Angelus.get_ephemeride(datetime) do
      print(ephemeride)
    else
      {:error, _reason} -> Mix.raise("datetime must be an ISO 8601 instant with an offset")
    end
  end

  def run(_args), do: Mix.raise("usage: mix angelus.ephemeride DATETIME")

  defp print(ephemeride) do
    Mix.shell().info("UTC: #{DateTime.to_iso8601(ephemeride.datetime)}")

    sidereal_time = ephemeride.sidereal_time

    Mix.shell().info(
      "Sidereal time: #{pad(sidereal_time.hour)}:#{pad(sidereal_time.minute)}:#{pad(sidereal_time.second)}"
    )

    Mix.shell().info("")

    ephemeride.positions
    |> rows()
    |> render_table(["Body", "Ecliptic lat (deg)", "Declination (deg)", "Motion"])
    |> Mix.shell().info()
  end

  defp rows(positions) do
    Enum.map(positions, fn position ->
      [
        Map.fetch!(@names, position.body),
        format_angle(position.lat),
        format_angle(position.decl),
        Atom.to_string(position.motion)
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

  defp format_angle(angle), do: :erlang.float_to_binary(angle, decimals: 4) <> "deg"

  defp pad(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")

  @shortdoc "Prints an Angelus ephemeris"
end
