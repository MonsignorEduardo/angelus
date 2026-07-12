defmodule Angelus.Astro.GeoidTest do
  use ExUnit.Case, async: true

  alias Angelus.Astro.Geoid
  alias Angelus.Astro.Location

  setup do
    path = Path.join(System.tmp_dir!(), "angelus-geoid-#{System.unique_integer([:positive])}.pgm")

    header = """
    P5
    # Description synthetic global test grid
    # Offset -10
    # Scale 0.5
    # Origin 90N 0E
    4 3
    65535
    """

    pixels =
      for value <- [0, 2, 4, 6, 10, 12, 14, 16, 20, 22, 24, 26], into: <<>> do
        <<value::unsigned-big-integer-size(16)>>
      end

    File.write!(path, header <> pixels)
    on_exit(fn -> File.rm(path) end)
    %{path: path}
  end

  test "opens GeographicLib PGM metadata", %{path: path} do
    assert {:ok, geoid} = Geoid.open(path)
    assert geoid.width == 4
    assert geoid.height == 3
    assert geoid.pixel_bytes == 2
    assert geoid.offset == -10.0
    assert geoid.scale == 0.5
  end

  test "reads exact grid points", %{path: path} do
    assert {:ok, geoid} = Geoid.open(path)
    assert Geoid.height(geoid, 0, 90) == {:ok, -4.0}
    assert Geoid.height(geoid, 90, 0) == {:ok, -10.0}
    assert Geoid.height(geoid, -90, 270) == {:ok, 3.0}
  end

  test "bilinearly interpolates and wraps longitude", %{path: path} do
    assert {:ok, geoid} = Geoid.open(path)
    assert Geoid.height(geoid, 45, 45) == {:ok, -7.0}
    assert Geoid.height(geoid, 0, -90) == Geoid.height(geoid, 0, 270)
  end

  test "converts orthometric elevation to ellipsoidal height", %{path: path} do
    assert {:ok, geoid} = Geoid.open(path)
    location = %Location{latitude: 0, longitude: 90, elevation_msl_m: 657}
    assert Location.ellipsoidal_height(location, geoid) == {:ok, 653.0}
  end

  test "rejects malformed and truncated grids", %{path: path} do
    malformed = path <> ".malformed"
    truncated = path <> ".truncated"
    File.write!(malformed, "P5\n4 3\n65535\n")
    File.write!(truncated, "P5\n# Offset 0\n# Scale 1\n4 3\n65535\n\0")

    on_exit(fn ->
      File.rm(malformed)
      File.rm(truncated)
    end)

    assert Geoid.open(malformed) == {:error, :invalid_geoid_file}
    assert Geoid.open(truncated) == {:error, :truncated_geoid_file}
  end
end
