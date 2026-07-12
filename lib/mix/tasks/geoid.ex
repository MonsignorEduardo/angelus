defmodule Mix.Tasks.Angelus.Geoid do
  @moduledoc "Downloads and validates the EGM2008 2.5-minute geoid grid."

  use Mix.Task

  alias Angelus.Astro.Geoid

  @url "https://sourceforge.net/projects/geographiclib/files/geoids-distrib/egm2008-2_5.zip/download"
  @pgm_sha256 "fab040a55dfabe782be89a89b2ba7e4a73183513a9813e24a3f80e7b6ed61dbf"
  @archive_entry ~c"geoids/egm2008-2_5.pgm"
  @filename "egm2008-2_5.pgm"

  @impl true
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: [force: :boolean])

    if rest != [] or invalid != [] do
      Mix.raise("unsupported options. Usage: mix angelus.geoid [--force]")
    end

    {:ok, _apps} = Application.ensure_all_started(:req)
    destination = destination_path()

    if Keyword.get(opts, :force, false) or not File.exists?(destination) do
      download_and_install!(destination)
    end

    case Geoid.open(destination) do
      {:ok, geoid} ->
        Mix.shell().info("EGM2008 geoid ready at #{destination} (#{geoid.width}x#{geoid.height})")

      {:error, reason} ->
        Mix.raise("invalid EGM2008 geoid: #{inspect(reason)}")
    end
  end

  defp download_and_install!(destination) do
    directory = Path.dirname(destination)
    File.mkdir_p!(directory)
    archive = Path.join(directory, ".egm2008-2_5.zip.tmp")
    extraction = Path.join(directory, ".egm2008-extract")
    File.rm_rf!(extraction)
    File.mkdir_p!(extraction)

    try do
      Mix.shell().info("Downloading EGM2008 2.5-minute geoid grid...")
      download!(@url, archive)

      case :zip.extract(String.to_charlist(archive),
             cwd: String.to_charlist(extraction),
             file_list: [@archive_entry]
           ) do
        {:ok, _files} -> :ok
        {:error, reason} -> Mix.raise("failed to extract EGM2008 archive: #{inspect(reason)}")
      end

      extracted = Path.join([extraction, "geoids", @filename])
      verify_checksum!(extracted)
      File.rename!(extracted, destination)
    after
      File.rm(archive)
      File.rm_rf(extraction)
    end
  end

  defp download!(url, destination) do
    response = Req.get!(url, redirect: true, max_redirects: 10, decode_body: false)

    unless response.status in 200..299 do
      Mix.raise("failed to download EGM2008: HTTP #{response.status}")
    end

    File.write!(destination, response.body, [:binary])
  end

  defp verify_checksum!(path) do
    actual = sha256(path)

    if actual != @pgm_sha256 do
      Mix.raise("EGM2008 checksum mismatch: expected #{@pgm_sha256}, got #{actual}")
    end
  end

  defp sha256(path) do
    context = :crypto.hash_init(:sha256)

    context =
      File.open!(path, [:read, :binary], fn io ->
        hash_stream(io, context)
      end)

    context |> :crypto.hash_final() |> Base.encode16(case: :lower)
  end

  defp hash_stream(io, context) do
    case IO.binread(io, 1_048_576) do
      data when is_binary(data) -> hash_stream(io, :crypto.hash_update(context, data))
      :eof -> context
      {:error, reason} -> Mix.raise("failed to checksum EGM2008: #{inspect(reason)}")
    end
  end

  defp destination_path do
    case Geoid.default_path() do
      {:ok, path} -> path
      {:error, reason} -> Mix.raise("cannot resolve Angelus priv directory: #{inspect(reason)}")
    end
  end

  @shortdoc "Downloads the EGM2008 2.5-minute geoid grid"
end
