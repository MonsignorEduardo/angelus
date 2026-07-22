defmodule Angelus.Ephemeride.Options do
  @moduledoc false

  alias Angelus.Observer

  @kernel_options [:base_path, :replace]
  @supported_options [:observer | @kernel_options]

  @type result :: %{
          kernel_options: [Angelus.Motor.load_kernel_option()],
          observer: Observer.t() | nil
        }

  @spec split(keyword()) :: {:ok, result()} | {:error, term()}
  def split(options) when is_list(options) do
    with :ok <- validate_keyword_options(options),
         :ok <- reject_unknown_options(options),
         {:ok, observer} <- validate_observer(Keyword.fetch(options, :observer)) do
      {:ok,
       %{
         kernel_options: Keyword.take(options, @kernel_options),
         observer: observer
       }}
    end
  end

  def split(_options), do: {:error, {:invalid_options, :expected_keyword_list}}

  defp validate_keyword_options(options) do
    if Keyword.keyword?(options),
      do: :ok,
      else: {:error, {:invalid_options, :expected_keyword_list}}
  end

  defp reject_unknown_options(options) do
    case Enum.find(options, fn {key, _value} -> key not in @supported_options end) do
      nil -> :ok
      option -> {:error, {:unsupported_option, option}}
    end
  end

  defp validate_observer(:error), do: {:ok, nil}
  defp validate_observer({:ok, observer}), do: Observer.validate(observer)
end
