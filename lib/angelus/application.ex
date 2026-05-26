defmodule Angelus.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [Angelus.Spice.Supervisor]

    Supervisor.start_link(children, strategy: :one_for_one, name: Angelus.Supervisor)
  end
end
