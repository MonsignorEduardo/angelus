defmodule Angelus.AngleTest do
  use ExUnit.Case, async: true

  test "normalize wraps to 0 inclusive and 360 exclusive" do
    assert Angelus.Angle.normalize(0) == 0.0
    assert Angelus.Angle.normalize(360) == 0.0
    assert Angelus.Angle.normalize(-1) == 359.0
    assert Angelus.Angle.normalize(721) == 1.0
  end

  test "distance uses minimum angular distance" do
    assert Angelus.Angle.distance(359, 1) == 2.0
    assert Angelus.Angle.distance(10, 350) == 20.0
  end

  test "signed distance preserves direction" do
    assert Angelus.Angle.signed_distance(359, 1) == 2.0
    assert Angelus.Angle.signed_distance(1, 359) == -2.0
  end

  test "rejects non numeric angles" do
    assert Angelus.Angle.normalize("1") == {:error, :invalid_angle}
    assert Angelus.Angle.distance(1, "2") == {:error, :invalid_angle}
    assert Angelus.Angle.deg_to_rad(nil) == {:error, :invalid_angle}
  end
end
