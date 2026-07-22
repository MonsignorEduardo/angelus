defmodule Angelus.Ephemeride.OptionsTest do
  use ExUnit.Case, async: true

  alias Angelus.Ephemeride.Options

  test "separates kernel options from a normalized observer" do
    assert {:ok, result} =
             Options.split(
               base_path: "/kernels",
               replace: true,
               observer: [latitude_deg: 40.4168, longitude_deg: -3.7038, height_m: 667]
             )

    assert result.kernel_options == [base_path: "/kernels", replace: true]
    assert result.observer.latitude_deg == 40.4168
    assert result.observer.longitude_deg == -3.7038
    assert result.observer.height_km == 0.667
  end

  test "accepts kernel-only options" do
    assert {:ok, %{kernel_options: [replace: false], observer: nil}} =
             Options.split(replace: false)
  end

  test "rejects unknown and malformed options before kernel loading" do
    assert {:error, {:unsupported_option, {:timezone, "UTC"}}} =
             Options.split(timezone: "UTC")

    assert {:error, {:invalid_options, :expected_keyword_list}} = Options.split(%{})

    assert {:error, {:invalid_observer, {:missing_fields, [:height_m]}}} =
             Options.split(observer: [latitude_deg: 0, longitude_deg: 0])
  end
end
