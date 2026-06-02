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
    with {:ok, target} <- BodyCatalog.fetch(body) do
      dispatch_ephemeride(body, target, utc, opts)
    end
  end

  # ── Dispatch by target ──────────────────────────────────────────────────

  defp dispatch_ephemeride(body, %{spice_target: spice_target} = target, utc, opts)
       when is_binary(spice_target) do
    with {:ok, state} <- Angelus.Motor.ephemeride(spice_target, utc, []) do
      {:ok, state |> convert_angles(opts) |> Map.merge(state_metadata(body, target))}
    end
  end

  defp dispatch_ephemeride(body, _target, _utc, _opts),
    do: {:error, {:unsupported_native_body, body}}

  defp convert_angles(state, opts) do
    if :rad in opts do
      state
    else
      state
      |> Map.update!(:ecliptic_longitude, &rad_to_deg/1)
      |> Map.update!(:ecliptic_latitude, &rad_to_deg/1)
    end
  end

  defp rad_to_deg(rad), do: rad * 180.0 / :math.pi()

  # ── Metadata helpers ─────────────────────────────────────────────────────

  defp state_metadata(body, target) do
    %{
      body: body,
      spice_target: target.spice_target,
      spice_id: target.spice_id,
      target_kind: target.target_kind
    }
  end
end
