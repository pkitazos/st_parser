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

  describe "branch parser" do
    test "parses a simple branch with end continuation" do
      assert {:ok,
              [
                %ST.SBranch{
                  label: :request,
                  payload: :binary,
                  continue_as: %ST.SEnd{}
                }
              ], "", _, _, _} = ST.Parser.parse_branch("Request(string).end")
    end
  end

  describe "input type parser" do
    test "parses an input with a single branch" do
      assert {:ok,
              [
                %ST.SIn{
                  from: :server,
                  branches: [
                    %ST.SBranch{
                      label: :ack,
                      payload: :unit,
                      continue_as: %ST.SEnd{}
                    }
                  ]
                }
              ], "", _, _, _} = ST.Parser.parse_input("&Server:{ Ack(unit).end }")
    end

    test "parses an input with multiple branches" do
      assert {:ok,
              [
                %ST.SIn{
                  from: :server,
                  branches: [
                    %ST.SBranch{
                      label: :error,
                      payload: :binary,
                      continue_as: %ST.SEnd{}
                    },
                    %ST.SBranch{
                      label: :ack,
                      payload: :unit,
                      continue_as: %ST.SEnd{}
                    }
                  ]
                }
              ], "", _, _,
              _} = ST.Parser.parse_input("&Server:{ Ack(unit).end, Error(string).end }")
    end
  end

  describe "output type parser" do
    test "parses an output with a single branch" do
      assert {:ok,
              [
                %ST.SOut{
                  to: :client,
                  branches: [
                    %ST.SBranch{
                      label: :request,
                      payload: :binary,
                      continue_as: %ST.SEnd{}
                    }
                  ]
                }
              ], "", _, _, _} = ST.Parser.parse_output("+Client:{ Request(string).end }")
    end

    test "parses an output with complex payload" do
      assert {:ok,
              [
                %ST.SOut{
                  to: :peer,
                  branches: [
                    %ST.SBranch{
                      label: :data,
                      payload: {:tuple, [:binary, {:list, [:boolean]}]},
                      continue_as: %ST.SEnd{}
                    }
                  ]
                }
              ], "", _, _, _} = ST.Parser.parse_output("+Peer:{ Data((string, boolean[])).end }")
    end
  end

  describe "session type parser" do
    test "parses end type" do
      assert {:ok, [%ST.SEnd{}], "", _, _, _} = ST.Parser.parse_session_type("end")
    end

    test "parses input type" do
      assert {:ok, [%ST.SIn{}], _, _, _, _} =
               ST.Parser.parse_session_type("&Server:{ Ack(unit).end }")
    end

    test "parses output type" do
      assert {:ok, [%ST.SOut{}], _, _, _, _} =
               ST.Parser.parse_session_type("+Client:{ Request(string).end }")
    end
  end
end
