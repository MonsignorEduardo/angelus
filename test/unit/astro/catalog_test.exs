defmodule Angelus.Astro.CatalogTest do
  use ExUnit.Case, async: true

  alias Angelus.Astro.Catalog
  alias Angelus.Astro.Catalog.Target

  test "get_metadata returns Target structs" do
    assert {:ok, %Target{}} = Catalog.get_metadata(:sun)
    assert {:ok, %Target{}} = Catalog.get_metadata(:true_node)
  end

  test "get_metadata returns physical body metadata" do
    assert {:ok, %{spice_target: "SUN", spice_id: 10, target_kind: :body_center}} =
             Catalog.get_metadata(:sun)

    assert {:ok, %{spice_target: "MOON", spice_id: 301, target_kind: :body_center}} =
             Catalog.get_metadata(:moon)

    assert {:ok, %{spice_target: "MERCURY", spice_id: 199, target_kind: :body_center}} =
             Catalog.get_metadata(:mercury)

    assert {:ok, %{spice_target: "VENUS", spice_id: 299, target_kind: :body_center}} =
             Catalog.get_metadata(:venus)
  end

  test "get_metadata returns body center targets for outer planets" do
    assert {:ok,
            %{
              spice_target: "MARS",
              spice_id: 499,
              target_kind: :body_center
            }} = Catalog.get_metadata(:mars)

    assert {:ok, %{spice_target: "JUPITER", spice_id: 599, target_kind: :body_center}} =
             Catalog.get_metadata(:jupiter)

    assert {:ok, %{spice_target: "SATURN", spice_id: 699, target_kind: :body_center}} =
             Catalog.get_metadata(:saturn)

    assert {:ok, %{spice_target: "URANUS", spice_id: 799, target_kind: :body_center}} =
             Catalog.get_metadata(:uranus)

    assert {:ok, %{spice_target: "NEPTUNE", spice_id: 899, target_kind: :body_center}} =
             Catalog.get_metadata(:neptune)

    assert {:ok, %{spice_target: "PLUTO", spice_id: 999, target_kind: :body_center}} =
             Catalog.get_metadata(:pluto)
  end

  test "get_metadata returns mathematical point metadata" do
    assert {:ok, %{spice_target: "TRUE_NODE", target_kind: :lunar_node}} =
             Catalog.get_metadata(:true_node)

    assert {:ok, %{spice_target: "LILITH", target_kind: :lunar_apogee}} =
             Catalog.get_metadata(:lilith)
  end

  test "get_metadata returns minor planet metadata" do
    expected = %{
      chiron: {"2002060", 2_002_060},
      ceres: {"2000001", 2_000_001},
      pallas: {"2000002", 2_000_002},
      juno: {"2000003", 2_000_003},
      vesta: {"2000004", 2_000_004},
      eris: {"2136199", 2_136_199}
    }

    Enum.each(expected, fn {body, {spice_target, spice_id}} ->
      assert {:ok,
              %{
                spice_target: ^spice_target,
                spice_id: ^spice_id,
                target_kind: :minor_planet
              }} = Catalog.get_metadata(body)
    end)
  end

  test "get_catalog returns the public target catalog" do
    catalog = Catalog.get_catalog()

    assert %Target{spice_target: "SUN", spice_id: 10, target_kind: :body_center} = catalog.sun
    assert %Target{spice_target: "TRUE_NODE", target_kind: :lunar_node} = catalog.true_node
    refute Map.has_key?(catalog.sun, :calculation)
  end

  test "get_kernel returns kernels in load order" do
    assert Enum.map(Catalog.get_kernel(), & &1.file) == [
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
             "2002060.bsp",
             "2000001.bsp",
             "2000002.bsp",
             "2000003.bsp",
             "2000004.bsp",
             "2136199.bsp"
           ]
  end

  test "get_kernel includes remote URLs and checksummed Horizons kernels" do
    kernels = Map.new(Catalog.get_kernel(), &{&1.file, &1})

    assert %{
             source: %{
               kind: :url,
               url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de442.bsp"
             }
           } = kernels["de442.bsp"]

    assert %{source: %{kind: :url, url: url, sha256: sha256}} = kernels["2002060.bsp"]
    assert String.ends_with?(url, "/kernels-v0.1/2002060.bsp")
    assert byte_size(sha256) == 64
  end

  test "get_metadata rejects unsupported bodies" do
    assert {:error, {:unsupported_body, :sedna}} = Catalog.get_metadata(:sedna)
    assert {:error, {:unsupported_body, :south_node}} = Catalog.get_metadata(:south_node)
    assert {:error, {:unsupported_body, :mean_node}} = Catalog.get_metadata(:mean_node)
  end

  test "supported_bodies returns exactly the public bodies" do
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
      :lilith,
      :chiron,
      :ceres,
      :pallas,
      :juno,
      :vesta,
      :eris
    ]

    assert MapSet.new(Catalog.supported_bodies()) == MapSet.new(expected)
  end
end
