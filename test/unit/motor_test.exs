defmodule Angelus.MotorTest do
  use ExUnit.Case, async: false

  alias Angelus.Astro.Catalog
  alias Angelus.Motor.Server

  setup do
    directory =
      Path.join(System.tmp_dir!(), "angelus-motor-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)

    paths =
      Enum.map(Catalog.get_kernel(), fn kernel ->
        path = Path.join(directory, kernel.file)
        File.write!(path, "")
        path
      end)

    on_exit(fn -> File.rm_rf!(directory) end)
    %{paths: paths}
  end

  test "load_kernels validates unsupported kernels before native calls" do
    assert Angelus.Motor.load_kernels(["priv/kernels/custom.bsp"]) ==
             {:error, {:unsupported_kernel, "custom.bsp"}}
  end

  test "load_kernels rejects malformed and incorrectly typed options", %{paths: paths} do
    assert Angelus.Motor.load_kernels(paths, [:replace]) ==
             {:error, {:invalid_options, :expected_keyword_list}}

    assert Angelus.Motor.load_kernels(paths, replace: :yes) ==
             {:error, {:invalid_option, {:replace, :yes}}}

    assert Angelus.Motor.load_kernels(base_path: nil) ==
             {:error, {:invalid_option, {:base_path, nil}}}

    assert Angelus.Motor.load_kernels(paths, :invalid) ==
             {:error, {:invalid_kernel_set, :invalid_paths}}
  end

  test "default kernel paths are resolved from the application priv directory" do
    priv_dir = :angelus |> :code.priv_dir() |> List.to_string()
    expected_base = Path.join(priv_dir, "kernels")

    assert {:ok, metadata} = Angelus.Motor.load_kernels(replace: true)
    assert Enum.all?(metadata.kernels, &String.starts_with?(&1.path, expected_base <> "/"))

    restart_worker()
  end

  test "get_body validates target and datetime before native calls" do
    assert Angelus.Motor.get_body(:jupiter, ~U[1990-05-24 06:30:00Z]) ==
             {:error, :invalid_args}

    assert Angelus.Motor.get_body("JUPITER", :bad_datetime) == {:error, :invalid_args}
  end

  test "get_body uses fixed native defaults before native calls" do
    assert Angelus.Motor.get_body("JUPITER", ~U[1990-05-24 06:30:00Z]) ==
             {:error, :kernels_not_loaded}
  end

  test "get_math_point validates point and datetime before native calls" do
    assert Angelus.Motor.get_math_point(:true_node, ~U[1990-05-24 06:30:00Z]) ==
             {:error, :invalid_args}

    assert Angelus.Motor.get_math_point("TRUE_NODE", :bad_datetime) == {:error, :invalid_args}

    assert Angelus.Motor.get_math_point("TRUE_NODE", ~U[1990-05-24 06:30:00Z]) ==
             {:error, :kernels_not_loaded}
  end

  test "rejects concurrent loads while a kernel operation is in progress", %{paths: paths} do
    for kernel_state <- [:loading, :replacing] do
      :sys.replace_state(Server, &%{&1 | kernel_state: kernel_state})

      assert Server.load_kernels(paths, []) ==
               {:error, :kernel_operation_in_progress}
    end

    :sys.replace_state(Server, &%{&1 | kernel_state: :unloaded})
  end

  test "a native request deadline clears pending work and restarts the worker" do
    test_pid = self()
    tag = make_ref()
    timer = Process.send_after(self(), :unused_timer, 60_000)

    old_port =
      :sys.replace_state(Server, fn state ->
        waiter = %{kind: :body, from: {test_pid, tag}, meta: %{}, timer: timer}
        %{state | pending: %{99 => waiter}, kernel_state: :loaded, metadata: %{test: true}}
      end).port

    send(Server, {:request_timeout, 99})

    assert_receive {^tag, {:error, :worker_timeout}}, 1_000

    state = :sys.get_state(Server)
    assert state.pending == %{}
    assert state.kernel_state == :unloaded
    assert state.metadata == nil
    assert is_port(state.port)
    refute state.port == old_port
  end

  test "a malformed worker response fails pending work and restarts the worker" do
    test_pid = self()
    tag = make_ref()
    timer = Process.send_after(self(), :unused_timer, 60_000)

    old_port =
      :sys.replace_state(Server, fn state ->
        waiter = %{kind: :body, from: {test_pid, tag}, meta: %{}, timer: timer}
        %{state | pending: %{100 => waiter}, kernel_state: :loaded, metadata: %{test: true}}
      end).port

    send(Server, {old_port, {:data, "not json"}})

    assert_receive {^tag, {:error, :worker_protocol_error}}, 1_000

    state = :sys.get_state(Server)
    assert state.pending == %{}
    assert state.kernel_state == :unloaded
    assert state.metadata == nil
    assert is_port(state.port)
    refute state.port == old_port
  end

  defp restart_worker do
    state = :sys.get_state(Server)
    send(Server, {state.port, {:data, "not json"}})

    Enum.reduce_while(1..100, nil, fn _, _ ->
      if :sys.get_state(Server).port != state.port do
        {:halt, :ok}
      else
        Process.sleep(10)
        {:cont, nil}
      end
    end)
  end
end
