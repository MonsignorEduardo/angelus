defmodule Mix.Tasks.Angelus.Validate.Horizons do
  @moduledoc "Validates or regenerates local JPL Horizons fixtures."

  use Mix.Task

  @fixture Path.join(["test", "fixtures", "horizons", "de442_positions.json"])

  @impl true
  def run(args) do
    case OptionParser.parse(args, strict: [check: :boolean, write: :boolean]) do
      {[check: true], [], []} ->
        check!()

      {[write: true], [], []} ->
        write!()

      {opts, [], []} when opts in [[], [check: false], [write: false]] ->
        help()

      {_opts, _rest, _invalid} ->
        Mix.raise("usage: mix angelus.validate.horizons --check | --write")
    end
  end

  defp check! do
    unless File.exists?(@fixture) do
      Mix.raise(
        "missing fixture #{@fixture}; run mix angelus.validate.horizons --write to generate it"
      )
    end

    with {:ok, body} <- File.read(@fixture),
         {:ok, fixture} <- Jason.decode(body),
         :ok <- validate_fixture(fixture) do
      Mix.shell().info("Horizons fixture is structurally valid: #{@fixture}")
    else
      {:error, reason} -> Mix.raise("invalid Horizons fixture: #{inspect(reason)}")
    end
  end

  @spec write!() :: no_return()
  defp write! do
    Mix.raise(
      "--write requires live JPL Horizons query support, which is not implemented in this first v0.1 scaffold"
    )
  end

  defp help do
    Mix.shell().info("Usage: mix angelus.validate.horizons --check | --write")
  end

  defp validate_fixture(%{"cases" => cases} = fixture) when is_list(cases) do
    required = [
      "source",
      "kernel",
      "lsk",
      "pck",
      "gm",
      "observer",
      "abcorr",
      "frame_base",
      "output"
    ]

    cond do
      Enum.any?(required, &(not Map.has_key?(fixture, &1))) -> {:error, :missing_fixture_metadata}
      Enum.empty?(cases) -> {:error, :empty_cases}
      true -> validate_cases(cases)
    end
  end

  defp validate_fixture(_fixture), do: {:error, :invalid_fixture_shape}

  defp validate_cases(cases) do
    required = [
      "datetime_utc",
      "body",
      "spice_target",
      "spice_id",
      "target_kind",
      "longitude",
      "latitude",
      "distance_au"
    ]

    case Enum.find(cases, fn case_ -> Enum.any?(required, &(not Map.has_key?(case_, &1))) end) do
      nil -> :ok
      _case -> {:error, :invalid_case_shape}
    end
  end

  @shortdoc "Validates JPL Horizons fixtures"
end
