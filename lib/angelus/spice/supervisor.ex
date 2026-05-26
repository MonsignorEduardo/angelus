defmodule Angelus.Spice.Supervisor do
  @moduledoc """
  Supervises the pool of `Angelus.Spice.Server` workers.

  v0.1 starts a single server with `restart: :permanent`.
  The structure allows scaling to N workers without API changes.
  """

  use Supervisor

  @impl true
  def init(_opts) do
    children = [
      {Angelus.Spice.Server, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
end
