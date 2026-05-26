defmodule Angelus.SpiceTest do
  use ExUnit.Case, async: false

  test "body_target exposes physical body metadata" do
    assert {:ok,
            %{
              spice_target: "JUPITER",
              spice_id: 599,
              target_kind: :body_center,
              required_spk: "jup349.bsp"
            }} = Angelus.Spice.body_target(:jupiter)
  end

  test "body_target exposes v0.1 ephemeris points" do
    assert {:ok, %{target_kind: :lunar_node, calculation: :true_lunar_node}} =
             Angelus.Spice.body_target(:true_node)

    assert {:ok, %{target_kind: :lunar_node, calculation: :mean_lunar_node}} =
             Angelus.Spice.body_target(:mean_node)

    assert {:ok, %{spice_target: "CHIRON", spice_id: 2_060, target_kind: :minor_planet}} =
             Angelus.Spice.body_target(:chiron)

    assert {:ok, %{target_kind: :lunar_apogee, calculation: :mean_lunar_apogee}} =
             Angelus.Spice.body_target(:lilith)
  end

  test "body_target rejects unsupported bodies" do
    assert Angelus.Spice.body_target(:ceres) == {:error, {:unsupported_body, :ceres}}
  end

  test "load_kernels validates unsupported kernels before native calls" do
    assert Angelus.Spice.load_kernels(["priv/kernels/custom.bsp"]) ==
             {:error, {:unsupported_kernel, "custom.bsp"}}
  end
end
