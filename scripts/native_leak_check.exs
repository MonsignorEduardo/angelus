#!/usr/bin/env elixir

worker =
  System.get_env("ANGELUS_WORKER") ||
    Path.expand("../_build/dev/lib/angelus/priv/angelus_worker", __DIR__)

unless File.exists?(worker) do
  IO.puts(:stderr, "angelus_worker not found: #{worker}")
  IO.puts(:stderr, "Run ANGELUS_FORCE_BUILD=1 mix compile first, or set ANGELUS_WORKER.")
  System.halt(1)
end

requests = [
  %{id: 1, payload: ~s({"id":1,"op":"ping"}), ok: true},
  %{id: 2, payload: ~s({"id":2,"op":"clear_kernels"}), ok: true},
  %{id: 3, payload: ~s({"id":3,"op":"unknown"}), ok: false},
  %{id: 0, payload: ~s({not json), ok: false},
  %{id: 4, payload: ~s({"id":4}), ok: false},
  %{id: 5, payload: ~s({"id":5,"op":"load_kernels","paths":[]}), ok: true},
  %{
    id: 6,
    payload: ~s({"id":6,"op":"math_point","point":"TRUE_NODE","utc":"bad"}),
    ok: false
  }
]

unless System.argv() == [] do
  IO.puts(:stderr, "usage: elixir scripts/native_leak_check.exs")
  System.halt(1)
end

unless System.find_executable("valgrind") do
  IO.puts(:stderr, "valgrind executable not found")
  System.halt(1)
end

defmodule PacketLog do
  def decode(<<length::32-big, rest::binary>>, acc) when byte_size(rest) >= length do
    <<payload::binary-size(length), remaining::binary>> = rest
    decode(remaining, [payload | acc])
  end

  def decode(<<>>, acc), do: Enum.reverse(acc)
  def decode(_partial, acc), do: Enum.reverse(["<truncated packet>" | acc])
end

IO.puts("native valgrind worker: #{worker}")
IO.puts("native valgrind requests: #{length(requests)}")

Enum.each(requests, fn request ->
  IO.puts("  request #{request.id} expect_ok=#{request.ok} payload=#{request.payload}")
end)

input =
  requests
  |> Enum.map(fn request ->
    payload = request.payload
    <<byte_size(payload)::32-big, payload::binary>>
  end)
  |> IO.iodata_to_binary()

id = System.unique_integer([:positive])
input_path = Path.join(System.tmp_dir!(), "angelus-valgrind-input-#{id}")
output_path = Path.join(System.tmp_dir!(), "angelus-valgrind-output-#{id}")
File.write!(input_path, input)

{output, status} =
  System.cmd(
    "sh",
    [
      "-c",
      "valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=definite,possible --error-exitcode=99 -- \"$1\" < \"$2\" > \"$3\"",
      "angelus-valgrind",
      worker,
      input_path,
      output_path
    ],
    stderr_to_stdout: true
  )

File.rm(input_path)

responses =
  output_path
  |> File.read!()
  |> PacketLog.decode([])

File.rm(output_path)

IO.puts("native valgrind exit status: #{status}")

IO.puts("native worker responses: #{length(responses)}")

Enum.each(responses, fn response ->
  IO.puts("  response #{response}")
end)

IO.puts("native valgrind output:")
IO.binwrite(output)

cond do
  status == 0 ->
    IO.puts("native valgrind completed: #{length(requests)} requests")

  status == 99 ->
    IO.puts(:stderr, "native valgrind found memory errors or leaks")

  true ->
    IO.puts(:stderr, "native valgrind failed with exit status #{status}")
end

System.halt(if(status == 0, do: 0, else: status))
