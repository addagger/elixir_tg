defmodule TgTest do
  use ExUnit.Case
  doctest Tg

  test "greets the world" do
    assert Tg.hello() == :world
  end
end
