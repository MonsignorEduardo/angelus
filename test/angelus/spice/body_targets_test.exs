defmodule Angelus.Spice.BodyTargetsTest do
  use ExUnit.Case, async: true

  alias Angelus.Spice.BodyTargets

  test "fetch returns physical body metadata" do
    assert {:ok, %{spice_target: "SUN", spice_id: 10, target_kind: :body_center}} =
             BodyTargets.fetch(:sun)

    assert {:ok, %{spice_target: "MOON", spice_id: 301, target_kind: :body_center}} =
             BodyTargets.fetch(:moon)

    assert {:ok, %{spice_target: "MERCURY", spice_id: 199, target_kind: :body_center}} =
             BodyTargets.fetch(:mercury)

    assert {:ok, %{spice_target: "VENUS", spice_id: 299, target_kind: :body_center}} =
             BodyTargets.fetch(:venus)
  end

  test "fetch returns body center targets with required SPK for outer planets" do
    assert {:ok,
            %{
              spice_target: "MARS",
              spice_id: 499,
              target_kind: :body_center,
              required_spk: "mar099.bsp"
            }} = BodyTargets.fetch(:mars)

    assert {:ok, %{spice_target: "JUPITER", spice_id: 599, required_spk: "jup349.bsp"}} =
             BodyTargets.fetch(:jupiter)

    assert {:ok, %{spice_target: "SATURN", spice_id: 699, required_spk: "sat459.bsp"}} =
             BodyTargets.fetch(:saturn)

    assert {:ok, %{spice_target: "URANUS", spice_id: 799, required_spk: "ura184_part-1.bsp"}} =
             BodyTargets.fetch(:uranus)

    assert {:ok, %{spice_target: "NEPTUNE", spice_id: 899, required_spk: "nep105.bsp"}} =
             BodyTargets.fetch(:neptune)

    assert {:ok, %{spice_target: "PLUTO", spice_id: 999, required_spk: "plu060.bsp"}} =
             BodyTargets.fetch(:pluto)
  end

  test "fetch returns mathematical point metadata" do
    assert {:ok, %{target_kind: :lunar_node, calculation: :true_lunar_node}} =
             BodyTargets.fetch(:true_node)

    assert {:ok, %{target_kind: :lunar_node, calculation: :mean_lunar_node}} =
             BodyTargets.fetch(:mean_node)

    assert {:ok, %{target_kind: :lunar_apogee, calculation: :mean_lunar_apogee}} =
             BodyTargets.fetch(:lilith)
  end

  test "fetch returns minor planet metadata for chiron" do
    assert {:ok, %{spice_target: "CHIRON", spice_id: 2_060, target_kind: :minor_planet}} =
             BodyTargets.fetch(:chiron)
  end

  test "fetch rejects unsupported bodies" do
    assert {:error, {:unsupported_body, :ceres}} = BodyTargets.fetch(:ceres)
    assert {:error, {:unsupported_body, :south_node}} = BodyTargets.fetch(:south_node)
    assert {:error, {:unsupported_body, "sun"}} = BodyTargets.fetch("sun")
  end

  test "supported_bodies returns all v0.1 bodies" do
    bodies = BodyTargets.supported_bodies()
    expected = [:sun, :moon, :mercury, :venus, :mars, :jupiter, :saturn, :uranus, :neptune, :pluto,
                :true_node, :mean_node, :chiron, :lilith]

    Enum.each(expected, fn b -> assert b in bodies, "missing #{b}" end)
  end
end
