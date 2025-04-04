defmodule ST.ParserTest do
  use ExUnit.Case

  describe "identifier parser" do
    test "converts CamelCase to snake_case atoms" do
      assert {:ok, [:client_request], "", _, _, _} = ST.Parser.parse_identifier("ClientRequest")
      assert {:ok, [:server], "", _, _, _} = ST.Parser.parse_identifier("Server")
      assert {:ok, [:ping_message], "", _, _, _} = ST.Parser.parse_identifier("PingMessage")
    end

    test "handles underscores" do
      assert {:ok, [:already_snake], "", _, _, _} = ST.Parser.parse_identifier("already_snake")

      assert {:ok, [:with_numbers_123], "", _, _, _} =
               ST.Parser.parse_identifier("with_numbers_123")
    end
  end

  describe "basic type parser" do
    test "recognizes and maps basic types" do
      assert {:ok, [:binary], "", _, _, _} = ST.Parser.parse_basic_type("string")
      assert {:ok, [:number], "", _, _, _} = ST.Parser.parse_basic_type("number")
      assert {:ok, [:unit], "", _, _, _} = ST.Parser.parse_basic_type("unit")
      assert {:ok, [:boolean], "", _, _, _} = ST.Parser.parse_basic_type("boolean")
    end
  end

  describe "list type parser" do
    test "recognizes list types and wraps them correctly" do
      assert {:ok, [{:list, [:binary]}], "", _, _, _} = ST.Parser.payload_type("string[]")
      assert {:ok, [{:list, [:number]}], "", _, _, _} = ST.Parser.payload_type("number[]")
      assert {:ok, [{:list, [:boolean]}], "", _, _, _} = ST.Parser.payload_type("boolean[]")
    end
  end

  describe "tuple type parser" do
    test "recognizes simple tuples" do
      assert {:ok, [{:tuple, [:binary, :number]}], "", _, _, _} =
               ST.Parser.parse_tuple("(string, number)")
    end

    test "handles whitespace in tuples" do
      assert {:ok, [{:tuple, [:binary, :number]}], "", _, _, _} =
               ST.Parser.parse_tuple("(string , number)")
    end

    test "recognizes tuple with list elements" do
      assert {:ok, [{:tuple, [:binary, {:list, [:boolean]}]}], "", _, _, _} =
               ST.Parser.parse_tuple("(string, boolean[])")
    end

    test "recognizes single element tuples" do
      assert {:ok, [{:tuple, [:unit]}], "", _, _, _} =
               ST.Parser.parse_tuple("(unit)")
    end

    # This test will pass once nested tuples are properly implemented
    test "recognizes nested tuples" do
      assert {:ok, [{:tuple, [:binary, {:tuple, [:number, :boolean]}]}], "", _, _, _} =
               ST.Parser.parse_tuple("(string, (number, boolean))")
    end
  end

  describe "end type parser" do
    test "recognizes end terminal" do
      assert {:ok, [%ST.SEnd{}], "", _, _, _} = ST.Parser.parse_end("end")
    end
  end
end
