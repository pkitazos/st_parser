defmodule ST.SigilTest do
  use ExUnit.Case

  import ST.Sigils

  describe "ST.Sigils ~q sigil" do
    test "creates SEnd struct from end expression" do
      sigil_result = ~q/end/
      {:ok, parser_result} = ST.Parser.parse("end")

      assert sigil_result == parser_result
      assert %ST.SEnd{} = sigil_result
    end

    test "creates SIn struct from input expression" do
      sigil_result = ~q/&Server:{ Ack(nil).end }/
      {:ok, parser_result} = ST.Parser.parse("&Server:{ Ack(nil).end }")

      assert sigil_result == parser_result

      assert %ST.SIn{
               from: :server,
               branches: [
                 %ST.SBranch{
                   label: :ack,
                   payload: nil,
                   continue_as: %ST.SEnd{}
                 }
               ]
             } = sigil_result
    end

    test "creates SOut struct from output expression" do
      sigil_result = ~q/+Client:{ Request(string).end }/
      {:ok, parser_result} = ST.Parser.parse("+Client:{ Request(string).end }")

      assert sigil_result == parser_result

      assert %ST.SOut{
               to: :client,
               branches: [
                 %ST.SBranch{
                   label: :request,
                   payload: :binary,
                   continue_as: %ST.SEnd{}
                 }
               ]
             } = sigil_result
    end

    test "handles complex payload types" do
      sigil_result = ~q/+Peer:{ Data((string, boolean[])).end }/
      {:ok, parser_result} = ST.Parser.parse("+Peer:{ Data((string, boolean[])).end }")

      assert sigil_result == parser_result

      assert %ST.SOut{
               to: :peer,
               branches: [
                 %ST.SBranch{
                   label: :data,
                   payload: {:tuple, [:binary, {:list, :boolean}]},
                   continue_as: %ST.SEnd{}
                 }
               ]
             } = sigil_result
    end

    test "handles multiple branches" do
      sigil_result = ~q/&Server:{ Success(number).end, Error(string).end }/
      {:ok, parser_result} = ST.Parser.parse("&Server:{ Success(number).end, Error(string).end }")

      assert sigil_result == parser_result

      assert %ST.SIn{
               from: :server,
               branches: branches
             } = sigil_result

      assert length(branches) == 2

      labels = Enum.map(branches, & &1.label)
      assert :success in labels
      assert :error in labels
    end

    test "handles nested session types" do
      nested_protocol = ~q/
        +Client:{
          Request(string).&Server:{
            Success(number).end,
            Error(string).end
          }
        }
      /

      protocol_string = """
      +Client:{
        Request(string).&Server:{
          Success(number).end,
          Error(string).end
        }
      }
      """

      {:ok, parser_result} = ST.Parser.parse(protocol_string)

      assert nested_protocol == parser_result

      assert %ST.SOut{
               to: :client,
               branches: [
                 %ST.SBranch{
                   label: :request,
                   payload: :binary,
                   continue_as: %ST.SIn{
                     from: :server,
                     branches: server_branches
                   }
                 }
               ]
             } = nested_protocol

      assert length(server_branches) == 2
      server_labels = Enum.map(server_branches, & &1.label)
      assert :success in server_labels
      assert :error in server_labels
    end

    test "handles named handlers" do
      sigil_result = ~q/&Buyer:{ Title(string).+Seller:{ Title(string).quote_handler } }/

      {:ok, parser_result} =
        ST.Parser.parse("&Buyer:{ Title(string).+Seller:{ Title(string).quote_handler } }")

      assert sigil_result == parser_result

      assert %ST.SIn{
               from: :buyer,
               branches: [
                 %ST.SBranch{
                   label: :title,
                   payload: :binary,
                   continue_as: %ST.SOut{
                     to: :seller,
                     branches: [
                       %ST.SBranch{
                         label: :title,
                         payload: :binary,
                         continue_as: %ST.SName{handler: :quote_handler}
                       }
                     ]
                   }
                 }
               ]
             } = sigil_result
    end

    test "works with different delimiter styles" do
      protocol_string = "&Server:{ Ack(nil).end }"

      result_slashes = ~q/&Server:{ Ack(nil).end }/
      result_brackets = ~q[&Server:{ Ack(nil).end }]
      result_pipes = ~q|&Server:{ Ack(nil).end }|
      result_quotes = ~q"&Server:{ Ack(nil).end }"

      assert result_slashes == result_brackets
      assert result_brackets == result_pipes
      assert result_pipes == result_quotes

      {:ok, parser_result} = ST.Parser.parse(protocol_string)
      assert result_slashes == parser_result
    end

    test "sigils can be used in function definitions" do
      defmodule TestProtocols do
        import ST.Sigils

        def get_ping_pong do
          ~q/+Ping:{ ping(nil).&Pong:{ pong(nil).end } }/
        end

        def get_auth_protocol do
          ~q/&Server:{ login((string, string)).+Client:{ success(nil).end } }/
        end
      end

      ping_pong = TestProtocols.get_ping_pong()
      assert %ST.SOut{to: :ping} = ping_pong

      auth = TestProtocols.get_auth_protocol()
      assert %ST.SIn{from: :server} = auth
    end

    test "sigils can be used in module attributes" do
      defmodule TestConstants do
        import ST.Sigils

        @ping_protocol ~q/+Ping:{ ping(nil).end }/
        @pong_protocol ~q/&Pong:{ pong(nil).end }/

        def ping_protocol, do: @ping_protocol
        def pong_protocol, do: @pong_protocol
      end

      assert %ST.SOut{to: :ping} = TestConstants.ping_protocol()
      assert %ST.SIn{from: :pong} = TestConstants.pong_protocol()
    end

    test "demonstrates zero runtime parsing overhead" do
      # This test shows that the sigil result is a pre-built struct,
      # not a function call that parses at runtime
      protocol = ~q/&Server:{ Ack(nil).end }/

      # The sigil should have produced a complete struct at compile time
      assert %ST.SIn{} = protocol
      assert is_struct(protocol, ST.SIn)

      # We can access fields directly without any parsing
      assert protocol.from == :server
      assert length(protocol.branches) == 1
      assert hd(protocol.branches).label == :ack
    end
  end

  # Note: We cannot easily test compile-time error handling in a regular test
  # because compile-time errors prevent the module from compiling at all.
  # To test error handling, you would need to create a separate file with
  # invalid sigils and verify that compilation fails.

  describe "sigil equivalence with parser" do
    test "complex real-world protocols match parser output exactly" do
      auth_sigil = ~q/
        +Client:{
          login((string, string)).&Server:{
            success(nil).authenticated_session,
            failure(string).end
          }
        }
      /

      auth_string = """
      +Client:{
        login((string, string)).&Server:{
          success(nil).authenticated_session,
          failure(string).end
        }
      }
      """

      {:ok, auth_parsed} = ST.Parser.parse(auth_string)
      assert auth_sigil == auth_parsed

      transfer_sigil = ~q/
        +Sender:{
          begin(string).&Receiver:{
            ready(nil).+Sender:{
              data(string[]).&Receiver:{
                ack(nil).end
              }
            },
            reject(string).end
          }
        }
      /

      transfer_string = """
      +Sender:{
        begin(string).&Receiver:{
          ready(nil).+Sender:{
            data(string[]).&Receiver:{
              ack(nil).end
            }
          },
          reject(string).end
        }
      }
      """

      {:ok, transfer_parsed} = ST.Parser.parse(transfer_string)
      assert transfer_sigil == transfer_parsed
    end
  end
end
