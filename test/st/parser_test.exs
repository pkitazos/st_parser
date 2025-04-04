defmodule ST.ParserTest do
  use ExUnit.Case

  # Test the public API functions from ST.Parser
  describe "ST.Parser.parse" do
    test "parses end type" do
      assert {:ok, %ST.SEnd{}} = ST.Parser.parse("end")
    end

    test "parses input type with single branch" do
      assert {:ok,
              %ST.SIn{
                from: :server,
                branches: [
                  %ST.SBranch{
                    label: :ack,
                    payload: :unit,
                    continue_as: %ST.SEnd{}
                  }
                ]
              }} = ST.Parser.parse("&Server:{ Ack(unit).end }")
    end

    test "parses input type with multiple branches" do
      assert {:ok,
              %ST.SIn{
                from: :server,
                branches: [
                  %ST.SBranch{
                    label: :ack,
                    payload: :unit,
                    continue_as: %ST.SEnd{}
                  },
                  %ST.SBranch{
                    label: :error,
                    payload: :binary,
                    continue_as: %ST.SEnd{}
                  }
                ]
              }} = ST.Parser.parse("&Server:{ Error(string).end, Ack(unit).end }")
    end

    test "parses output type with single branch" do
      assert {:ok,
              %ST.SOut{
                to: :client,
                branches: [
                  %ST.SBranch{
                    label: :request,
                    payload: :binary,
                    continue_as: %ST.SEnd{}
                  }
                ]
              }} = ST.Parser.parse("+Client:{ Request(string).end }")
    end

    test "parses output type with complex payload" do
      assert {:ok,
              %ST.SOut{
                to: :peer,
                branches: [
                  %ST.SBranch{
                    label: :data,
                    payload: {:tuple, [:binary, {:list, [:boolean]}]},
                    continue_as: %ST.SEnd{}
                  }
                ]
              }} = ST.Parser.parse("+Peer:{ Data((string, boolean[])).end }")
    end

    test "parses nested session types" do
      # Client sends a request, Server responds with Success or Error
      request_response = """
      +Client:{
        Request(string).&Server:{
          Success(number).end,
          Error(string).end
        }
      }
      """

      assert {:ok,
              %ST.SOut{
                to: :client,
                branches: [
                  %ST.SBranch{
                    label: :request,
                    payload: :binary,
                    continue_as: %ST.SIn{
                      from: :server,
                      branches: [
                        %ST.SBranch{
                          label: :error,
                          payload: :binary,
                          continue_as: %ST.SEnd{}
                        },
                        %ST.SBranch{
                          label: :success,
                          payload: :number,
                          continue_as: %ST.SEnd{}
                        }
                      ]
                    }
                  }
                ]
              }} = ST.Parser.parse(request_response)
    end

    test "parses complex nested session types" do
      # A more complex protocol with multiple levels of nesting
      complex_type = """
      +Client:{
        Request(string).&Server:{
          Error(string).end,
          Success((number, string[])).+Client:{
            Acknowledge(unit).end
          }
        }
      }
      """

      assert {:ok,
              %ST.SOut{
                to: :client,
                branches: [
                  %ST.SBranch{
                    label: :request,
                    payload: :binary,
                    continue_as: %ST.SIn{
                      from: :server,
                      branches: [
                        %ST.SBranch{
                          label: :success,
                          payload: {:tuple, [:number, {:list, [:binary]}]},
                          continue_as: %ST.SOut{
                            to: :client,
                            branches: [
                              %ST.SBranch{
                                label: :acknowledge,
                                payload: :unit,
                                continue_as: %ST.SEnd{}
                              }
                            ]
                          }
                        },
                        %ST.SBranch{
                          label: :error,
                          payload: :binary,
                          continue_as: %ST.SEnd{}
                        }
                      ]
                    }
                  }
                ]
              }} = ST.Parser.parse(complex_type)
    end

    test "parses deep recursive session types" do
      # A protocol that could represent a chat sequence with multiple exchanges
      chat_protocol = """
      +Client:{
        Message(string).&Server:{
          Received(unit).+Client:{
            Continue(unit).&Server:{
              Ready(unit).+Client:{
                Message(string).&Server:{
                  Received(unit).end
                }
              },
              Busy(unit).end
            },
            Quit(unit).end
          }
        }
      }
      """

      # This validates the parser can handle complex recursive structures
      {:ok, parsed} = ST.Parser.parse(chat_protocol)

      # Ensure the outermost type is an output to client
      assert %ST.SOut{to: :client} = parsed

      # Get the first message branch
      [%ST.SBranch{label: :message, continue_as: continue1}] = parsed.branches

      # Ensure it continues with an input from server
      assert %ST.SIn{from: :server} = continue1

      # From the received branch, it should continue to an output to client
      [%ST.SBranch{label: :received, continue_as: continue2}] = continue1.branches
      assert %ST.SOut{to: :client} = continue2

      # The client then can continue or quit
      # Two branches
      assert [_, _] = continue2.branches
    end

    test "handles whitespace variations" do
      # Minimal whitespace
      assert {:ok, %ST.SOut{}} = ST.Parser.parse("+Client:{Request(string).end}")

      # Extra whitespace
      assert {:ok, %ST.SOut{}} = ST.Parser.parse("+Client:{ Request(string).end }")
    end

    test "returns error for invalid session types" do
      # Invalid input
      # Incomplete
      assert {:error, _} = ST.Parser.parse("&Server")
      # Empty branches
      assert {:error, _} = ST.Parser.parse("&Server:{}")

      # Invalid output
      # Incomplete
      assert {:error, _} = ST.Parser.parse("+Client")
      # Empty branches
      assert {:error, _} = ST.Parser.parse("+Client:{}")

      # Invalid branch
      # No input/output prefix
      assert {:error, _} = ST.Parser.parse("Request(string).end")

      # Invalid payload
      # Empty payload
      assert {:error, _} = ST.Parser.parse("+Client:{ Request().end }")
      # Invalid type
      assert {:error, _} = ST.Parser.parse("+Client:{ Request(invalid).end }")

      # Syntax errors
      # Comma instead of dot
      assert {:error, _} = ST.Parser.parse("+Client:{ Request(string),end }")
      # Missing dot
      assert {:error, _} = ST.Parser.parse("+Client:{ Request(string) end }")
    end
  end

  describe "ST.Parser.parse!" do
    test "returns parsed structure directly on success" do
      assert %ST.SEnd{} = ST.Parser.parse!("end")

      assert %ST.SIn{
               from: :server,
               branches: [
                 %ST.SBranch{
                   label: :ack,
                   payload: :unit,
                   continue_as: %ST.SEnd{}
                 }
               ]
             } = ST.Parser.parse!("&Server:{ Ack(unit).end }")
    end

    test "raises exception on failure" do
      assert_raise RuntimeError, fn -> ST.Parser.parse!("invalid") end
      assert_raise RuntimeError, fn -> ST.Parser.parse!("&Server:{ Ack.end }") end
    end
  end

  describe "ST.Parser.parse_type" do
    test "parses basic types" do
      assert {:ok, :binary} = ST.Parser.parse_type("string")
      assert {:ok, :number} = ST.Parser.parse_type("number")
      assert {:ok, :unit} = ST.Parser.parse_type("unit")
      assert {:ok, :boolean} = ST.Parser.parse_type("boolean")
    end

    test "parses list types" do
      assert {:ok, {:list, [:binary]}} = ST.Parser.parse_type("string[]")
      assert {:ok, {:list, [:number]}} = ST.Parser.parse_type("number[]")
      assert {:ok, {:list, [:boolean]}} = ST.Parser.parse_type("boolean[]")
    end

    test "parses tuple types" do
      assert {:ok, {:tuple, [:binary, :number]}} = ST.Parser.parse_type("(string, number)")

      assert {:ok, {:tuple, [:binary, {:list, [:boolean]}]}} =
               ST.Parser.parse_type("(string, boolean[])")

      assert {:ok, {:tuple, [:unit]}} = ST.Parser.parse_type("(unit)")
    end

    test "parses nested tuple types" do
      assert {:ok, {:tuple, [:binary, {:tuple, [:number, :boolean]}]}} =
               ST.Parser.parse_type("(string, (number, boolean))")

      assert {:ok, {:tuple, [:binary, {:tuple, [:number, {:tuple, [:boolean, :unit]}]}]}} =
               ST.Parser.parse_type("(string, (number, (boolean, unit)))")
    end

    test "parses tuples with mixed types" do
      assert {:ok, {:tuple, [:binary, {:list, [:number]}, :boolean]}} =
               ST.Parser.parse_type("(string, number[], boolean)")
    end

    test "returns error for invalid types" do
      # Unknown type
      assert {:error, _} = ST.Parser.parse_type("invalid")
      # Empty list
      assert {:error, _} = ST.Parser.parse_type("[]")
      # Incomplete brackets
      assert {:error, _} = ST.Parser.parse_type("string[")
      # Incomplete tuple
      assert {:error, _} = ST.Parser.parse_type("(string,")
      # Missing type after comma
      assert {:error, _} = ST.Parser.parse_type("(string, )")
    end
  end

  describe "ST.Parser.parse_type!" do
    test "returns parsed type directly on success" do
      assert :binary = ST.Parser.parse_type!("string")
      assert {:list, [:boolean]} = ST.Parser.parse_type!("boolean[]")
      assert {:tuple, [:binary, :number]} = ST.Parser.parse_type!("(string, number)")
    end

    test "raises exception on failure" do
      assert_raise RuntimeError, fn -> ST.Parser.parse_type!("invalid") end
      assert_raise RuntimeError, fn -> ST.Parser.parse_type!("(string,)") end
    end
  end

  describe "common protocol patterns" do
    test "parses ping-pong protocol" do
      ping_pong = """
      +Ping:{
        Ping(unit).&Pong:{
          Pong(unit).end
        }
      }
      """

      assert {:ok,
              %ST.SOut{
                to: :ping,
                branches: [
                  %ST.SBranch{
                    label: :ping,
                    payload: :unit,
                    continue_as: %ST.SIn{
                      from: :pong,
                      branches: [
                        %ST.SBranch{
                          label: :pong,
                          payload: :unit,
                          continue_as: %ST.SEnd{}
                        }
                      ]
                    }
                  }
                ]
              }} = ST.Parser.parse(ping_pong)
    end

    test "parses authentication protocol" do
      auth_protocol = """
      +Client:{
        Login((string, string)).&Server:{
          Success(unit).+Client:{
            Request(string).&Server:{
              Response(string).end
            }
          },
          Failure(string).end
        }
      }
      """

      {:ok, parsed} = ST.Parser.parse(auth_protocol)

      assert %ST.SOut{to: :client} = parsed
      [%ST.SBranch{label: :login}] = parsed.branches

      # Login payload should be a tuple of two strings
      assert {:tuple, [:binary, :binary]} = parsed.branches |> hd |> Map.get(:payload)
    end

    test "parses file transfer protocol" do
      transfer_protocol = """
      +Sender:{
        Begin(string).&Receiver:{
          Ready(unit).+Sender:{
            Data(string[]).&Receiver:{
              Ack(unit).+Sender:{
                Complete(unit).end,
                More(string[]).&Receiver:{
                  Ack(unit).end
                }
              }
            }
          },
          Reject(string).end
        }
      }
      """

      # Just verify it parses correctly
      assert {:ok, %ST.SOut{}} = ST.Parser.parse(transfer_protocol)
    end
  end

  # The following tests access the Core parsers directly for better coverage
  # of the internal parsers

  describe "Core.parse_session_type" do
    test "parses end type" do
      assert {:ok, [%ST.SEnd{}], "", _, _, _} = ST.Parser.Core.parse_session_type("end")
    end

    test "parses input type" do
      assert {:ok, [%ST.SIn{}], _, _, _, _} =
               ST.Parser.Core.parse_session_type("&Server:{ Ack(unit).end }")
    end

    test "parses output type" do
      assert {:ok, [%ST.SOut{}], _, _, _, _} =
               ST.Parser.Core.parse_session_type("+Client:{ Request(string).end }")
    end
  end

  describe "Core.parse_branch" do
    test "parses a simple branch with end continuation" do
      assert {:ok,
              [
                %ST.SBranch{
                  label: :request,
                  payload: :binary,
                  continue_as: %ST.SEnd{}
                }
              ], "", _, _, _} = ST.Parser.Core.parse_branch("Request(string).end")
    end

    test "parses a branch with complex payload" do
      assert {:ok,
              [
                %ST.SBranch{
                  label: :data,
                  payload: {:tuple, [:binary, {:list, [:boolean]}]},
                  continue_as: %ST.SEnd{}
                }
              ], "", _, _, _} = ST.Parser.Core.parse_branch("Data((string, boolean[])).end")
    end

    test "parses a branch with nested continuation" do
      assert {:ok,
              [
                %ST.SBranch{
                  label: :request,
                  payload: :binary,
                  continue_as: %ST.SOut{
                    to: :client,
                    branches: [
                      %ST.SBranch{
                        label: :response,
                        payload: :number,
                        continue_as: %ST.SEnd{}
                      }
                    ]
                  }
                }
              ], "", _, _,
              _} =
               ST.Parser.Core.parse_branch("Request(string).+Client:{ Response(number).end }")
    end
  end

  describe "Core.parse_input" do
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
              ], "", _, _, _} = ST.Parser.Core.parse_input("&Server:{ Ack(unit).end }")
    end

    test "parses an input with multiple branches" do
      assert {:ok,
              [
                %ST.SIn{
                  from: :server,
                  branches: [
                    %ST.SBranch{
                      label: :ack,
                      payload: :unit,
                      continue_as: %ST.SEnd{}
                    },
                    %ST.SBranch{
                      label: :error,
                      payload: :binary,
                      continue_as: %ST.SEnd{}
                    }
                  ]
                }
              ], "", _, _,
              _} = ST.Parser.Core.parse_input("&Server:{ Error(string).end, Ack(unit).end }")
    end
  end

  describe "Core.parse_output" do
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
              ], "", _, _, _} = ST.Parser.Core.parse_output("+Client:{ Request(string).end }")
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
              ], "", _, _,
              _} = ST.Parser.Core.parse_output("+Peer:{ Data((string, boolean[])).end }")
    end
  end

  describe "Core.payload_type" do
    test "parses basic types" do
      assert {:ok, [:binary], "", _, _, _} = ST.Parser.Core.payload_type("string")
      assert {:ok, [:number], "", _, _, _} = ST.Parser.Core.payload_type("number")
      assert {:ok, [:unit], "", _, _, _} = ST.Parser.Core.payload_type("unit")
      assert {:ok, [:boolean], "", _, _, _} = ST.Parser.Core.payload_type("boolean")
    end

    test "parses list types" do
      assert {:ok, [{:list, [:binary]}], "", _, _, _} = ST.Parser.Core.payload_type("string[]")
      assert {:ok, [{:list, [:number]}], "", _, _, _} = ST.Parser.Core.payload_type("number[]")
      assert {:ok, [{:list, [:boolean]}], "", _, _, _} = ST.Parser.Core.payload_type("boolean[]")
    end

    test "parses tuple types" do
      assert {:ok, [{:tuple, [:binary, :number]}], "", _, _, _} =
               ST.Parser.Core.payload_type("(string, number)")
    end
  end

  describe "Core.parse_tuple" do
    test "parses simple tuples" do
      assert {:ok, [{:tuple, [:binary, :number]}], "", _, _, _} =
               ST.Parser.Core.parse_tuple("(string, number)")
    end

    test "recognises tuple with list elements" do
      assert {:ok, [{:tuple, [:binary, {:list, [:boolean]}]}], "", _, _, _} =
               ST.Parser.Core.parse_tuple("(string, boolean[])")
    end

    test "recognises single element tuples" do
      assert {:ok, [{:tuple, [:unit]}], "", _, _, _} =
               ST.Parser.Core.parse_tuple("(unit)")
    end

    test "recognises nested tuples" do
      assert {:ok, [{:tuple, [:binary, {:tuple, [:number, :boolean]}]}], "", _, _, _} =
               ST.Parser.Core.parse_tuple("(string, (number, boolean))")
    end
  end
end
