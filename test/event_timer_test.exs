defmodule EventTimerTest do
  use ExUnit.Case
  doctest EventTimer

  test "greets the world" do
    assert EventTimer.hello() == :world
  end
end
