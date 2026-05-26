defmodule Angelus.SpiceTest do
  use ExUnit.Case, async: false

  test "load_kernels validates unsupported kernels before native calls" do
    assert Angelus.Spice.load_kernels(["priv/kernels/custom.bsp"]) ==
             {:error, {:unsupported_kernel, "custom.bsp"}}
  end

  test "state validates target and ET before native calls" do
    assert Angelus.Spice.state(:jupiter, -302_378_400.0) == {:error, :invalid_target}
    assert Angelus.Spice.state("JUPITER", :bad_et) == {:error, :invalid_et}
  end
end
