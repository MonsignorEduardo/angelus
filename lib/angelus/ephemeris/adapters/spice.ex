defmodule Angelus.Ephemeris.Adapters.Spice do
  @moduledoc "SPICE-backed adapter for `Angelus.Ephemeris`."

  @behaviour Angelus.Ephemeris.Adapter

  alias Angelus.Ephemeris.BodyCatalog

  @doc "Returns a full ephemeride BodyPosition for a UTC datetime and body.
  
  Options:
    * `:rad` — return longitude/latitude in radians
    * `:angles` — explicit alias for degrees (default)
  "
  @impl true
  @spec get_ephemeride(DateTime.t(), atom(), [atom()]) ::
          {:ok, map()} | {:error, term()}
  def get_ephemeride(%DateTime{} = utc, body, opts) when is_list(opts) do
    units = if :rad in opts, do: "rad", else: "deg"

    with {:ok, target} <- BodyCatalog.fetch(body) do
      dispatch_ephemeride(body, target, utc, units)
    end
  end

  # ── Dispatch by target kind ──────────────────────────────────────────────

defp dispatch_ephemeride(body, %{target_kind: :lunar_node, calculation: calculation} = target, utc, units) do
    with {:ok, state} <- Angelus.Motor.lunar_node(calculation, utc, units: units) do
      {:ok, Map.merge(state, node_metadata(body, target))}
    end
end

defp dispatch_ephemeride(body, %{spice_target: spice_target} = target, utc, units)
     when is_binary(spice_target) do
    with {:ok, state} <- Angelus.Motor.ephemeride(spice_target, utc, units: units) do
      {:ok, Map.merge(state, state_metadata(body, target))}
    end
end

defp dispatch_ephemeride(body, _target, _utc, _units),
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
