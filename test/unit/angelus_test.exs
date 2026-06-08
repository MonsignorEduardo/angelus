defmodule AngelusTest do
  use ExUnit.Case, async: false

  test "load_kernels returns motor validation errors" do
    assert Angelus.load_kernels(["priv/kernels/custom.bsp"]) ==
             {:error, {:unsupported_kernel, "custom.bsp"}}
  end
end
