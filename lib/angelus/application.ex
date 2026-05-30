defmodule Angelus.Application do
  @moduledoc "OTP application entry point for Angelus."

  use Application

  @impl true
  @spec start(Application.start_type(), term()) :: Supervisor.on_start()
  def start(_type, _args) do
    children = [Angelus.Motor.Supervisor]

    Supervisor.start_link(children, strategy: :one_for_one, name: Angelus.Supervisor)
  end
end
