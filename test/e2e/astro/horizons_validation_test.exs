defmodule Angelus.Astro.HorizonsValidationTest do
  use ExUnit.Case, async: false

  @moduletag :e2e

  @fixture Path.join(["test", "support", "fixtures", "horizons", "de442_positions.json"])
  @default_tolerances %{
    "distance_au" => 1.0e-8
  }

  setup_all do
    assert {:ok, Angelus.Astro.Adapters.Spice} = Angelus.load_kernels(replace: true)
    :ok
  end

  test "SPICE-backed positions match JPL Horizons fixture" do
    fixture = read_fixture!()
    tolerances = Map.merge(@default_tolerances, Map.get(fixture, "tolerances", %{}))

    Enum.each(fixture["cases"], fn case_ ->
      body = body_atom!(case_["body"])
      datetime = datetime!(case_["datetime_utc"])

      assert {:ok, %{^body => position}} = Angelus.Astro.positions([body], datetime)

      assert_close(position.distance_au, case_["distance_au"], tolerances["distance_au"], case_)
    end)
  end

  defp read_fixture! do
    unless File.exists?(@fixture) do
      flunk("missing Horizons fixture #{@fixture}; generate it from real JPL Horizons output")
    end

    assert {:ok, body} = File.read(@fixture)
    assert {:ok, %{"cases" => cases} = fixture} = Jason.decode(body)
    assert is_list(cases)

    fixture
  end

  defp body_atom!(body) when is_binary(body),
    do: body |> String.downcase() |> String.to_existing_atom()

  defp datetime!(datetime_utc) do
    assert {:ok, datetime, 0} = DateTime.from_iso8601(datetime_utc)
    datetime
  end

  defp assert_close(actual, expected, tolerance, case_) do
    assert abs(actual - expected) <= tolerance,
           "#{case_["body"]} at #{case_["datetime_utc"]}: expected #{expected}, got #{actual}, tolerance #{tolerance}"
  end
end
