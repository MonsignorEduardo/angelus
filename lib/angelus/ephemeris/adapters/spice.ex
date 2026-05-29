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
    with {:ok, target} <- BodyCatalog.fetch(body) do
      dispatch_state(body, target, et)
    end
  end

  # ── Dispatch by target kind ──────────────────────────────────────────────

  defp dispatch_state(body, %{target_kind: :lunar_node, calculation: calculation} = target, et) do
    with {:ok, state} <- Angelus.Spice.lunar_node(calculation, et) do
      {:ok, Map.merge(state, node_metadata(body, target))}
    end
  end

  defp dispatch_state(body, %{spice_target: spice_target} = target, et)
       when is_binary(spice_target) do
    with {:ok, state} <- Angelus.Spice.state(spice_target, et) do
      {:ok, Map.merge(state, state_metadata(body, target))}
    end
  end

  defp dispatch_state(body, _target, _et),
    do: {:error, {:unsupported_native_body, body}}

  # ── Metadata helpers ─────────────────────────────────────────────────────

  defp state_metadata(body, target) do
    %{
      body: body,
      spice_target: target.spice_target,
      spice_id: target.spice_id,
      target_kind: target.target_kind
    }
  end

  defp node_metadata(body, target) do
    %{
      body: body,
      spice_target: nil,
      spice_id: nil,
      target_kind: target.target_kind,
      calculation: target.calculation
    }
  end
end
