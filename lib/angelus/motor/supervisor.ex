defmodule Angelus.Motor.Supervisor do
  @moduledoc """
  Supervises the pool of `Angelus.Motor.Server` workers.

  v0.1 starts a single server with `restart: :permanent`.
  The structure allows scaling to N workers without API changes.
  """

  use Supervisor

  @impl true
  @spec init(keyword()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(_opts) do
    children = [
      {Angelus.Motor.Server, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc "Starts the Motor supervisor."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
end
