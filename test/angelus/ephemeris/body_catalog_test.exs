defmodule Angelus.Ephemeris.BodyCatalogTest do
  use ExUnit.Case, async: true

  alias Angelus.Ephemeris.BodyCatalog

  test "fetch returns physical body metadata" do
    assert {:ok, %{spice_target: "SUN", spice_id: 10, target_kind: :body_center}} =
             BodyCatalog.fetch(:sun)

    assert {:ok, %{spice_target: "MOON", spice_id: 301, target_kind: :body_center}} =
             BodyCatalog.fetch(:moon)

    assert {:ok, %{spice_target: "MERCURY", spice_id: 199, target_kind: :body_center}} =
             BodyCatalog.fetch(:mercury)

    assert {:ok, %{spice_target: "VENUS", spice_id: 299, target_kind: :body_center}} =
             BodyCatalog.fetch(:venus)
  end

  test "fetch returns body center targets with required SPK for outer planets" do
    assert {:ok,
            %{
              spice_target: "MARS",
              spice_id: 499,
              target_kind: :body_center,
              required_spk: "mar099.bsp"
            }} = BodyCatalog.fetch(:mars)

    assert {:ok, %{spice_target: "JUPITER", spice_id: 599, required_spk: "jup349.bsp"}} =
             BodyCatalog.fetch(:jupiter)

    assert {:ok, %{spice_target: "SATURN", spice_id: 699, required_spk: "sat459.bsp"}} =
             BodyCatalog.fetch(:saturn)

    assert {:ok, %{spice_target: "URANUS", spice_id: 799, required_spk: "ura184_part-1.bsp"}} =
             BodyCatalog.fetch(:uranus)

    assert {:ok, %{spice_target: "NEPTUNE", spice_id: 899, required_spk: "nep105.bsp"}} =
             BodyCatalog.fetch(:neptune)

    assert {:ok, %{spice_target: "PLUTO", spice_id: 999, required_spk: "plu060.bsp"}} =
             BodyCatalog.fetch(:pluto)
  end

  test "fetch returns mathematical point metadata" do
    assert {:ok, %{target_kind: :lunar_node, calculation: :true_lunar_node}} =
             BodyCatalog.fetch(:true_node)

    assert {:ok, %{target_kind: :lunar_node, calculation: :mean_lunar_node}} =
             BodyCatalog.fetch(:mean_node)

    assert {:ok, %{target_kind: :lunar_apogee, calculation: :mean_lunar_apogee}} =
             BodyCatalog.fetch(:lilith)
  end

  test "fetch returns minor planet metadata for chiron" do
    assert {:ok, %{spice_target: "CHIRON", spice_id: 2_060, target_kind: :minor_planet}} =
             BodyCatalog.fetch(:chiron)
  end

  test "fetch rejects unsupported bodies" do
    assert {:error, {:unsupported_body, :ceres}} = BodyCatalog.fetch(:ceres)
    assert {:error, {:unsupported_body, :south_node}} = BodyCatalog.fetch(:south_node)
    assert {:error, {:unsupported_body, "sun"}} = BodyCatalog.fetch("sun")
  end

  test "supported_bodies returns all v0.1 bodies" do
    bodies = BodyCatalog.supported_bodies()

    expected = [
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
      :mean_node,
      :chiron,
      :lilith
    ]

    Enum.each(expected, fn body -> assert body in bodies, "missing #{body}" end)
  end
end
