defmodule Angelus.Astro.Geoid do
  @moduledoc """
  Random-access reader for GeographicLib geoid grids in binary PGM format.

  GeographicLib encodes geoid undulation as `offset + scale * pixel`. This
  module uses bilinear interpolation over the global grid and reads only the
  four pixels surrounding each requested location.
  """

  @header_bytes 65_536
  @default_filename "egm2008-2_5.pgm"

  @enforce_keys [:path, :width, :height, :data_offset, :pixel_bytes, :offset, :scale]
  defstruct [:path, :width, :height, :data_offset, :pixel_bytes, :offset, :scale]

  @type t :: %__MODULE__{
          path: Path.t(),
          width: pos_integer(),
          height: pos_integer(),
          data_offset: non_neg_integer(),
          pixel_bytes: 1 | 2,
          offset: float(),
          scale: float()
        }

  @doc "Opens and validates a GeographicLib PGM geoid grid."
  @spec open(Path.t()) :: {:ok, t()} | {:error, term()}
  def open(path) when is_binary(path) do
    with {:ok, io} <- File.open(path, [:read, :binary]),
         {:ok, header} <- read_header(io),
         :ok <- File.close(io),
         {:ok, geoid} <- parse_header(path, header),
         :ok <- validate_file_size(geoid) do
      {:ok, geoid}
    else
      {:error, _reason} = error -> error
    end
  end

  def open(_path), do: {:error, :invalid_geoid_path}

  @doc "Returns the default EGM2008 grid path under the Angelus priv directory."
  @spec default_path() :: {:ok, Path.t()} | {:error, term()}
  def default_path do
    case :code.priv_dir(:angelus) do
      {:error, reason} -> {:error, {:priv_dir_unavailable, reason}}
      priv_dir -> {:ok, Path.join([List.to_string(priv_dir), "geoid", @default_filename])}
    end
  end

  @doc "Opens the default EGM2008 2.5-minute grid."
  @spec open_default() :: {:ok, t()} | {:error, term()}
  def open_default do
    with {:ok, path} <- default_path(), do: open(path)
  end

  @doc "Returns EGM geoid undulation in metres at a geodetic coordinate."
  @spec height(t(), number(), number()) :: {:ok, float()} | {:error, term()}
  def height(%__MODULE__{} = geoid, latitude, longitude)
      when is_number(latitude) and is_number(longitude) and latitude >= -90 and latitude <= 90 do
    x = normalize_longitude(longitude) / 360.0 * geoid.width
    y = (90.0 - latitude) / 180.0 * (geoid.height - 1)

    x0 = x |> :math.floor() |> trunc() |> rem(geoid.width)
    x1 = rem(x0 + 1, geoid.width)
    y0 = y |> :math.floor() |> trunc() |> min(geoid.height - 1)
    y1 = min(y0 + 1, geoid.height - 1)
    tx = x - :math.floor(x)
    ty = y - :math.floor(y)

    with {:ok, [p00, p10, p01, p11]} <-
           read_pixels(geoid, [{x0, y0}, {x1, y0}, {x0, y1}, {x1, y1}]) do
      raw =
        p00 * (1.0 - tx) * (1.0 - ty) +
          p10 * tx * (1.0 - ty) +
          p01 * (1.0 - tx) * ty +
          p11 * tx * ty

      {:ok, geoid.offset + geoid.scale * raw}
    end
  end

  def height(%__MODULE__{}, latitude, _longitude) when is_number(latitude),
    do: {:error, {:latitude_out_of_range, latitude}}

  def height(%__MODULE__{}, _latitude, _longitude), do: {:error, :invalid_coordinates}
  def height(_geoid, _latitude, _longitude), do: {:error, :invalid_geoid}

  defp read_header(io) do
    case IO.binread(io, @header_bytes) do
      data when is_binary(data) -> {:ok, data}
      :eof -> {:error, :invalid_geoid_file}
      {:error, reason} -> {:error, {:geoid_read_failed, reason}}
    end
  end

  defp parse_header(path, header) do
    with {:ok, "P5", cursor} <- next_token(header, 0),
         {:ok, width_token, cursor} <- next_token(header, cursor),
         {:ok, height_token, cursor} <- next_token(header, cursor),
         {:ok, maxval_token, cursor} <- next_token(header, cursor),
         {width, ""} when width > 0 <- Integer.parse(width_token),
         {height, ""} when height > 1 <- Integer.parse(height_token),
         {maxval, ""} when maxval in 1..65_535 <- Integer.parse(maxval_token),
         {:ok, data_offset} <- data_offset(header, cursor),
         {:ok, offset} <- comment_number(header, "Offset"),
         {:ok, scale} <- comment_number(header, "Scale") do
      {:ok,
       %__MODULE__{
         path: path,
         width: width,
         height: height,
         data_offset: data_offset,
         pixel_bytes: if(maxval < 256, do: 1, else: 2),
         offset: offset,
         scale: scale
       }}
    else
      _other -> {:error, :invalid_geoid_file}
    end
  end

  defp next_token(data, cursor) do
    cursor = skip_separators(data, cursor)

    if cursor >= byte_size(data) do
      {:error, :invalid_geoid_file}
    else
      finish = scan_token(data, cursor)
      {:ok, binary_part(data, cursor, finish - cursor), finish}
    end
  end

  defp skip_separators(data, cursor) when cursor >= byte_size(data), do: cursor

  defp skip_separators(data, cursor) do
    case :binary.at(data, cursor) do
      byte when byte in [9, 10, 13, 32] -> skip_separators(data, cursor + 1)
      ?# -> skip_separators(data, skip_comment(data, cursor + 1))
      _byte -> cursor
    end
  end

  defp skip_comment(data, cursor) when cursor >= byte_size(data), do: cursor

  defp skip_comment(data, cursor) do
    if :binary.at(data, cursor) == ?\n, do: cursor + 1, else: skip_comment(data, cursor + 1)
  end

  defp scan_token(data, cursor) when cursor >= byte_size(data), do: cursor

  defp scan_token(data, cursor) do
    if :binary.at(data, cursor) in [9, 10, 13, 32, ?#],
      do: cursor,
      else: scan_token(data, cursor + 1)
  end

  defp data_offset(data, cursor) when cursor < byte_size(data) do
    case :binary.at(data, cursor) do
      ?\r ->
        if cursor + 1 < byte_size(data) and :binary.at(data, cursor + 1) == ?\n,
          do: {:ok, cursor + 2},
          else: {:ok, cursor + 1}

      byte when byte in [9, 10, 13, 32] ->
        {:ok, cursor + 1}

      _byte ->
        {:error, :invalid_geoid_file}
    end
  end

  defp data_offset(_data, _cursor), do: {:error, :invalid_geoid_file}

  defp comment_number(header, name) do
    regex = ~r/^#\s*#{name}\s+([^\s]+)\s*$/m

    case Regex.run(regex, header, capture: :all_but_first) do
      [value] ->
        case Float.parse(value) do
          {number, ""} -> {:ok, number}
          _other -> {:error, :invalid_geoid_file}
        end

      _other ->
        {:error, :invalid_geoid_file}
    end
  end

  defp validate_file_size(geoid) do
    expected = geoid.data_offset + geoid.width * geoid.height * geoid.pixel_bytes

    case File.stat(geoid.path) do
      {:ok, %{size: size}} when size >= expected -> :ok
      {:ok, _stat} -> {:error, :truncated_geoid_file}
      {:error, reason} -> {:error, {:geoid_stat_failed, reason}}
    end
  end

  defp read_pixels(geoid, coordinates) do
    case File.open(geoid.path, [:read, :binary], &read_coordinates(&1, geoid, coordinates)) do
      {:ok, result} -> result
      {:error, reason} -> {:error, {:geoid_open_failed, reason}}
    end
  end

  defp read_coordinates(io, geoid, coordinates) do
    Enum.reduce_while(coordinates, {:ok, []}, fn coordinate, {:ok, values} ->
      case read_pixel(io, geoid, coordinate) do
        {:ok, value} -> {:cont, {:ok, [value | values]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> reverse_pixels()
  end

  defp reverse_pixels({:ok, values}), do: {:ok, Enum.reverse(values)}
  defp reverse_pixels({:error, _reason} = error), do: error

  defp read_pixel(io, geoid, {x, y}) do
    offset = geoid.data_offset + (y * geoid.width + x) * geoid.pixel_bytes

    case :file.pread(io, offset, geoid.pixel_bytes) do
      {:ok, <<value::unsigned-big-integer-size(8)>>} when geoid.pixel_bytes == 1 ->
        {:ok, value}

      {:ok, <<value::unsigned-big-integer-size(16)>>} when geoid.pixel_bytes == 2 ->
        {:ok, value}

      _other ->
        {:error, :geoid_read_failed}
    end
  end

  defp normalize_longitude(longitude) do
    normalized = longitude - 360.0 * :math.floor(longitude / 360.0)
    if normalized == 360.0, do: 0.0, else: normalized
  end
end
