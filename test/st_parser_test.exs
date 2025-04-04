defmodule StParserTest do
  use ExUnit.Case
  doctest StParser

  test "greets the world" do
    assert StParser.hello() == :world
  end
end
