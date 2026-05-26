defmodule Angelus.Spice.KernelSetTest do
  use ExUnit.Case, async: true

  alias Angelus.Spice.KernelSet

  @required_files [
    "latest_leapseconds.tls",
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
    "plu060.bsp"
  ]

  # ── required_files / default_paths ──────────────────────────────────────

  test "required_files returns the complete v0.1 kernel list" do
    assert KernelSet.required_files() == @required_files
  end

  test "default_paths joins base_path with each required file" do
    paths = KernelSet.default_paths("/base")
    assert length(paths) == length(@required_files)
    assert "/base/latest_leapseconds.tls" in paths
    assert "/base/de442.bsp" in paths
    assert "/base/ura184_part-1.bsp" in paths
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

  test "metadata includes ephemeris :de442 and kernel_policy :default_modern" do
    meta = KernelSet.metadata(fake_paths())
    assert meta.ephemeris == :de442
    assert meta.kernel_policy == :default_modern
    assert meta.public_range == %{from: ~D[1900-01-01], to: ~D[2100-01-24]}
  end

  test "metadata kernels list has correct types" do
    meta = KernelSet.metadata(fake_paths())
    types = Enum.map(meta.kernels, & &1.type)
    assert :lsk in types
    assert :pck in types
    assert :spk in types
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
