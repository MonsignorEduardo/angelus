defmodule Angelus.MotorTest do
  use ExUnit.Case, async: false

  test "load_kernels validates unsupported kernels before native calls" do
    assert Angelus.Motor.load_kernels(["priv/kernels/custom.bsp"]) ==
             {:error, {:unsupported_kernel, "custom.bsp"}}
  end

  test "body validates target and datetime before native calls" do
    assert Angelus.Motor.body(:jupiter, ~U[1990-05-24 06:30:00Z], []) ==
             {:error, :invalid_args}

    assert Angelus.Motor.body("JUPITER", :bad_datetime, []) == {:error, :invalid_args}
  end

  test "body accepts supported geocentric options before native calls" do
    assert Angelus.Motor.body("JUPITER", ~U[1990-05-24 06:30:00Z],
             state: :geocentric,
             observer: :earth,
             frame: :j2000,
             abcorr: :none
           ) == {:error, :kernels_not_loaded}
  end

  test "body rejects unsupported state options before native calls" do
    assert Angelus.Motor.body("JUPITER", ~U[1990-05-24 06:30:00Z], state: :topocentric) ==
             {:error, {:unsupported_option, {:state, :topocentric}}}

    assert Angelus.Motor.body("JUPITER", ~U[1990-05-24 06:30:00Z], observer: :mars) ==
             {:error, {:unsupported_option, {:observer, :mars}}}

    assert Angelus.Motor.body("JUPITER", ~U[1990-05-24 06:30:00Z], frame: :bad) ==
             {:error, {:unsupported_option, {:frame, :bad}}}

    assert Angelus.Motor.body("JUPITER", ~U[1990-05-24 06:30:00Z], abcorr: :bad) ==
             {:error, {:unsupported_option, {:abcorr, :bad}}}
  end

  test "math_point validates point and datetime before native calls" do
    assert Angelus.Motor.math_point(:true_node, ~U[1990-05-24 06:30:00Z]) ==
             {:error, :invalid_args}

    assert Angelus.Motor.math_point("TRUE_NODE", :bad_datetime) == {:error, :invalid_args}

    assert Angelus.Motor.math_point("TRUE_NODE", ~U[1990-05-24 06:30:00Z]) ==
             {:error, :kernels_not_loaded}
  end
end
