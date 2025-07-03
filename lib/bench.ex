defmodule Bench do
  def async(count, fun) do
    IO.puts("Starting async Benchmark with #{count} processes...")

    {time, _} =
      :timer.tc(fn ->
        1..count
        |> Enum.map(fn _i -> Task.async(fun) end)
        |> Enum.map(&Task.await(&1, :infinity))
      end)

    throughput = round(1000000*count/time)
    IO.puts("Time spent: #{time} (#{throughput} operations/sec)\n")
  end

  def sync(count, fun) do
    IO.puts("Starting sync Benchmark...")

    {time, _} =
      :timer.tc(fn ->
        1..count
        |> Enum.map(fn _i -> fun.() end)
      end)

    throughput = round(1000000*count/time)
    IO.puts("Time spent: #{time} (#{throughput} operations/sec)\n")
  end
end
