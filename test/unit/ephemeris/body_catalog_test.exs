defmodule Angelus.Ephemeris.BodyCatalogTest do
  use ExUnit.Case, async: true

  alias Angelus.Ephemeris.BodyCatalog
  alias Angelus.Ephemeris.BodyCatalog.Target

  test "fetch returns Target structs" do
    assert {:ok, %Target{}} = BodyCatalog.fetch(:sun)
    assert {:ok, %Target{}} = BodyCatalog.fetch(:true_node)
  end

  test "fetch returns physical body metadata" do
    assert {:ok, %{spice_target: "SUN", spice_id: 10, target_kind: :body_center}} =
             BodyCatalog.fetch(:sun)

    assert {:ok, %{spice_target: "MOON", spice_id: 301, target_kind: :body_center}} =
             BodyCatalog.fetch(:moon)

    assert {:ok, %{spice_target: "MERCURY", spice_id: 199, target_kind: :body_center}} =
             BodyCatalog.fetch(:mercury)

    assert {:ok, %{spice_target: "VENUS", spice_id: 299, target_kind: :body_center}} =
             BodyCatalog.fetch(:venus)
  end

  test "fetch returns body center targets for outer planets" do
    assert {:ok,
            %{
              spice_target: "MARS",
              spice_id: 499,
              target_kind: :body_center
            }} = BodyCatalog.fetch(:mars)

    assert {:ok, %{spice_target: "JUPITER", spice_id: 599, target_kind: :body_center}} =
             BodyCatalog.fetch(:jupiter)

    assert {:ok, %{spice_target: "SATURN", spice_id: 699, target_kind: :body_center}} =
             BodyCatalog.fetch(:saturn)

    assert {:ok, %{spice_target: "URANUS", spice_id: 799, target_kind: :body_center}} =
             BodyCatalog.fetch(:uranus)

    assert {:ok, %{spice_target: "NEPTUNE", spice_id: 899, target_kind: :body_center}} =
             BodyCatalog.fetch(:neptune)

    assert {:ok, %{spice_target: "PLUTO", spice_id: 999, target_kind: :body_center}} =
             BodyCatalog.fetch(:pluto)
  end

  test "fetch returns mathematical point metadata" do
    assert {:ok,
            %{spice_target: "TRUE_NODE", target_kind: :lunar_node, calculation: :true_lunar_node}} =
             BodyCatalog.fetch(:true_node)

    assert {:ok,
            %{
              spice_target: "LILITH",
              target_kind: :lunar_apogee,
              calculation: :mean_lunar_apogee
            }} =
             BodyCatalog.fetch(:lilith)
  end

  test "fetch returns minor planet metadata" do
    expected = %{
      chiron: {"20002060", 20_002_060},
      ceres: {"20000001", 20_000_001},
      pallas: {"20000002", 20_000_002},
      juno: {"20000003", 20_000_003},
      vesta: {"20000004", 20_000_004},
      eris: {"20136199", 20_136_199}
    }

    Enum.each(expected, fn {body, {spice_target, spice_id}} ->
      assert {:ok,
              %{
                spice_target: ^spice_target,
                spice_id: ^spice_id,
                target_kind: :minor_planet,
                calculation: :spice_body_center
              }} = BodyCatalog.fetch(body)
    end)
  end

  test "required_files returns kernels in load order" do
    assert BodyCatalog.required_files() == [
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
  end

  test "sources include remote URLs and bundled minor planet kernels" do
    sources = BodyCatalog.sources()

    assert %{
             kind: :url,
             url: "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/de442.bsp"
           } =
             sources["de442.bsp"]

    assert %{kind: :bundled, path: path} = sources["20002060.bsp"]
    assert String.ends_with?(path, "native/src/kernels/20002060.bsp")
  end

  test "metadata includes catalog-level policy and date ranges" do
    paths = Enum.map(BodyCatalog.required_files(), &"/kernels/#{&1}")
    metadata = BodyCatalog.metadata(paths)

    assert metadata.ephemeris == :de442
    assert metadata.kernel_policy == :default
    assert metadata.public_range == %{from: ~D[1900-01-01], to: ~D[2100-01-24]}

    assert %{file: "de442.bsp", range: {~D[1549-12-31], ~D[2650-01-25]}} =
             Enum.find(metadata.kernels, &(&1.file == "de442.bsp"))
  end

  test "fetch rejects unsupported bodies" do
    assert {:error, {:unsupported_body, :sedna}} = BodyCatalog.fetch(:sedna)
    assert {:error, {:unsupported_body, :south_node}} = BodyCatalog.fetch(:south_node)
    assert {:error, {:unsupported_body, :mean_node}} = BodyCatalog.fetch(:mean_node)
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

    assert MapSet.new(BodyCatalog.supported_bodies()) == MapSet.new(expected)
  end
end
