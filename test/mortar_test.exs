defmodule MortarTest do
  use ExUnit.Case
  doctest Mortar

  test "greets the world" do
    assert Mortar.hello() == :world
  end
end
