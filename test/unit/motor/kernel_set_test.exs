defmodule Angelus.Motor.KernelSetTest do
  use ExUnit.Case, async: true

  alias Angelus.Motor.KernelSet

  @required_files [
    "naif0012.tls",
    "pck00011.tpc",
    "gm_de440.tpc",
    "de442.bsp",
    "mar099.bsp",
    "jup349.bsp",
    "sat459.bsp",
    "ura184_part-1.bsp",
    "ura184_part-2.bsp",
    "ura184_part-3.bsp",
    "nep105.bsp",
    "plu060.bsp",
    "20002060.bsp",
    "20000001.bsp",
    "20000002.bsp",
    "20000003.bsp",
    "20000004.bsp",
    "20136199.bsp"
  ]

  # ── required_files / default_paths ──────────────────────────────────────

  test "required_files returns the complete v0.1 kernel list" do
    assert KernelSet.required_files() == @required_files
  end

  test "default_paths joins base_path with each required file" do
    paths = KernelSet.default_paths("/base")
    assert length(paths) == length(@required_files)
    assert "/base/naif0012.tls" in paths
    assert "/base/de442.bsp" in paths
    assert "/base/ura184_part-1.bsp" in paths
    assert "/base/20002060.bsp" in paths
  end

  # ── validate whitelist ───────────────────────────────────────────────────

  test "validate rejects unsupported SPK" do
    assert {:error, {:unsupported_kernel, "custom.bsp"}} =
             KernelSet.validate(fake_paths(extra: "custom.bsp"))
  end

  test "validate rejects de442s.bsp" do
    assert {:error, {:unsupported_kernel, "de442s.bsp"}} =
             KernelSet.validate(fake_paths(extra: "de442s.bsp"))
  end

  # ── TLS validation ───────────────────────────────────────────────────────

  test "validate rejects missing TLS" do
    paths = Enum.reject(fake_paths(), &String.ends_with?(&1, ".tls"))
    assert {:error, {:invalid_kernel_set, :missing_tls}} = KernelSet.validate(paths)
  end

  test "validate rejects multiple TLS" do
    paths = fake_paths() ++ ["/k/another.tls"]
    assert {:error, {:unsupported_kernel, "another.tls"}} = KernelSet.validate(paths)
  end

  # ── TPC validation ───────────────────────────────────────────────────────

  test "validate rejects missing pck00011.tpc" do
    paths = Enum.reject(fake_paths(), &String.contains?(&1, "pck00011"))

    assert {:error, {:invalid_kernel_set, {:missing_tpc, "pck00011.tpc"}}} =
             KernelSet.validate(paths)
  end

  test "validate rejects missing gm_de440.tpc" do
    paths = Enum.reject(fake_paths(), &String.contains?(&1, "gm_de440"))

    assert {:error, {:invalid_kernel_set, {:missing_tpc, "gm_de440.tpc"}}} =
             KernelSet.validate(paths)
  end

  # ── SPK validation ───────────────────────────────────────────────────────

  test "validate rejects missing de442.bsp" do
    paths = Enum.reject(fake_paths(), &String.contains?(&1, "de442.bsp"))

    assert {:error, {:invalid_kernel_set, {:missing_bsp, "de442.bsp"}}} =
             KernelSet.validate(paths)
  end

  test "validate rejects missing complementary SPK" do
    paths = Enum.reject(fake_paths(), &String.contains?(&1, "jup349"))

    assert {:error, {:invalid_kernel_set, {:missing_bsp, "jup349.bsp"}}} =
             KernelSet.validate(paths)
  end

  # ── File existence ───────────────────────────────────────────────────────

  test "validate rejects missing files on disk" do
    paths = Enum.map(@required_files, &"/nonexistent/#{&1}")
    assert {:error, {:kernel_file_missing, _path}} = KernelSet.validate(paths)
  end

  # ── metadata ────────────────────────────────────────────────────────────

  test "metadata includes ephemeris :de442 and kernel_policy :default" do
    meta = KernelSet.metadata(fake_paths())
    assert meta.ephemeris == :de442
    assert meta.kernel_policy == :default
    refute Map.has_key?(meta, :profile)
    assert meta.public_range == %{from: ~D[1900-01-01], to: ~D[2100-01-24]}
  end

  test "metadata kernels list has correct types" do
    meta = KernelSet.metadata(fake_paths())
    types = Enum.map(meta.kernels, & &1.type)
    assert :lsk in types
    assert :pck in types
    assert :spk in types
  end

  test "metadata includes minor planet kernels" do
    meta = KernelSet.metadata(fake_paths())

    expected = [
      {"20002060.bsp", "CHIRON", 20_002_060},
      {"20000001.bsp", "CERES", 20_000_001},
      {"20000002.bsp", "PALLAS", 20_000_002},
      {"20000003.bsp", "JUNO", 20_000_003},
      {"20000004.bsp", "VESTA", 20_000_004},
      {"20136199.bsp", "ERIS", 20_136_199}
    ]

    Enum.each(expected, fn {file, target, spice_id} ->
      assert Enum.any?(meta.kernels, fn kernel ->
               match?(
                 %{file: ^file, target: ^target, spice_id: ^spice_id, role: :minor_planet},
                 kernel
               )
             end)
    end)
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  # Build a list of fake (non-existing) paths for structural validation tests
  # that don't reach the file-existence check.
  defp fake_paths(extra: extra),
    do: fake_paths() ++ ["/kernels/#{extra}"]

  defp fake_paths do
    Enum.map(@required_files, &"/kernels/#{&1}")
  end
end
