defmodule AngelusTest do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!

  @spice_mock Angelus.Astro.AdapterMock

  test "get_positions with coordinates delegates to Astro" do
    datetime = ~U[1990-05-24 06:30:00Z]

    location = %Angelus.Astro.Location{
      latitude: 40.4,
      longitude: -3.7,
      elevation_msl_m: 667
    }

    body = %Angelus.Astro.Body{body: :sun}

    expect(@spice_mock, :get_position, fn ^datetime, :sun, ^location ->
      {:ok, body}
    end)

    assert Angelus.get_positions([:sun], datetime, location, @spice_mock) ==
             {:ok, %{sun: body}}
  end

  test "get_position with a location returns one body" do
    datetime = ~U[1990-05-24 06:30:00Z]
    location = %Angelus.Astro.Location{latitude: 40.4, longitude: -3.7}
    body = %Angelus.Astro.Body{body: :sun}

    expect(@spice_mock, :get_position, fn ^datetime, :sun, ^location -> {:ok, body} end)

    assert Angelus.get_position(:sun, datetime, location, @spice_mock) == {:ok, body}
  end

  test "load_kernels returns motor validation errors" do
    assert Angelus.load_kernels(["priv/kernels/custom.bsp"]) ==
             {:error, {:unsupported_kernel, "custom.bsp"}}
  end
end
