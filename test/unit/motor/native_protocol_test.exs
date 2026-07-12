defmodule Angelus.Motor.NativeProtocolTest do
  use ExUnit.Case, async: false

  setup do
    executable = :angelus |> :code.priv_dir() |> List.to_string() |> Path.join("angelus_worker")

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        {:packet, 4},
        :use_stdio
      ])

    on_exit(fn ->
      if Port.info(port), do: Port.close(port)
    end)

    %{port: port}
  end

  test "rejects invalid request IDs and continues serving", %{port: port} do
    assert %{"id" => -1, "ok" => false, "error" => "invalid id"} =
             request(port, %{"id" => 1.5, "op" => "ping"})

    assert %{"id" => -1, "ok" => false, "error" => "invalid id"} =
             request(port, %{"id" => "1", "op" => "ping"})

    assert %{"id" => 2, "ok" => true, "result" => "pong"} =
             request(port, %{"id" => 2, "op" => "ping"})
  end

  test "rejects absent and incorrectly typed operation fields", %{port: port} do
    assert %{"id" => 3, "ok" => false, "error" => "invalid body arguments"} =
             request(port, %{"id" => 3, "op" => "body", "target" => "MARS"})

    assert %{"id" => 4, "ok" => false, "error" => "invalid math_point arguments"} =
             request(port, %{
               "id" => 4,
               "op" => "math_point",
               "point" => 42,
               "utc" => "2000-01-01T12:00:00Z"
             })

    assert %{"id" => 5, "ok" => false, "error" => "invalid paths"} =
             request(port, %{"id" => 5, "op" => "load_kernels", "paths" => ["a", 42]})
  end

  test "rejects path arrays above the protocol limit instead of truncating", %{port: port} do
    paths = Enum.map(1..33, &"/tmp/kernel-#{&1}.bsp")

    assert %{"id" => 6, "ok" => false, "error" => "invalid paths"} =
             request(port, %{"id" => 6, "op" => "load_kernels", "paths" => paths})
  end

  test "rejects invalid topocentric observers and continues serving", %{port: port} do
    assert %{
             "id" => 7,
             "ok" => false,
             "error" => "invalid topocentric_body arguments"
           } =
             request(port, %{
               "id" => 7,
               "op" => "topocentric_body",
               "target" => "MOON",
               "utc" => "2000-01-01T12:00:00Z",
               "latitude_degrees" => 91,
               "longitude_degrees" => 0,
               "ellipsoidal_height_m" => 0
             })

    assert %{"id" => 8, "ok" => true, "result" => "pong"} =
             request(port, %{"id" => 8, "op" => "ping"})
  end

  defp request(port, payload) do
    true = Port.command(port, Jason.encode!(payload))

    receive do
      {^port, {:data, response}} -> Jason.decode!(response)
      {^port, {:exit_status, status}} -> flunk("worker exited with status #{status}")
    after
      1_000 -> flunk("worker did not respond")
    end
  end
end
