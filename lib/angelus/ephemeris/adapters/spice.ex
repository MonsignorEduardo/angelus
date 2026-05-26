defmodule Angelus.Ephemeris.Adapters.Spice do
  @moduledoc "SPICE-backed adapter for `Angelus.Ephemeris`."

  @behaviour Angelus.Ephemeris.Adapter

  alias Angelus.Ephemeris.BodyCatalog

  @doc "Converts UTC datetime to SPICE ephemeris time through `Angelus.Spice`."
  @impl true
  @spec utc_to_et(DateTime.t()) :: {:ok, float()} | {:error, term()}
  def utc_to_et(%DateTime{} = datetime), do: Angelus.Spice.utc_to_et(datetime)

  @doc "Returns SPICE-backed state data for a public ephemeris body atom."
  @impl true
  @spec state(atom(), float()) :: {:ok, map()} | {:error, term()}
  def state(body, et) do
    with {:ok, target} <- BodyCatalog.fetch(body),
         :ok <- validate_native_target(body, target),
         {:ok, state} <- Angelus.Spice.state(target.spice_target, et) do
      {:ok, Map.merge(state, state_metadata(body, target))}
    end
  end

  defp validate_native_target(_body, %{spice_target: target}) when is_binary(target), do: :ok
  defp validate_native_target(body, _target), do: {:error, {:unsupported_native_body, body}}

  defp state_metadata(body, target) do
    %{
      body: body,
      spice_target: target.spice_target,
      spice_id: target.spice_id,
      target_kind: target.target_kind
    }
  end
end
