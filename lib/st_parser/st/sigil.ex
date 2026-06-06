defmodule ST.Sigils do
  @moduledoc """
  Simple compile-time sigils for Session Types.

  Provides the ~q sigil for defining session types with compile-time parsing
  and validation.
  """

  @doc """
  Sigil for compile-time session type parsing.

  Parses the session type expression at compile time and expands to the
  corresponding ST struct. This provides compile-time validation and
  zero runtime overhead.

  ## Examples

      import ST.Sigils

      # Simple end session
      session = ~q/end/

      # Input session type
      session = ~q/&Server:{ Ack(nil).end }/

      # Output session type
      session = ~q/+Client:{ Request(string).end }/

      # Complex protocol
      session = ~q/
        &Server:{
          Request(string).+Client:{
            Response((string, number[])).end,
            Error(string).end
          }
        }
      /
  """
  defmacro sigil_q({:<<>>, _meta, [session_type_string]}, _modifiers) do
    case ST.Parser.parse(session_type_string) do
      {:ok, parsed_struct} ->
        quote do
          unquote(Macro.escape(parsed_struct))
        end

      {:error, reason} ->
        raise CompileError,
          description: "Invalid session type: #{reason}",
          file: __CALLER__.file,
          line: __CALLER__.line
    end
  end
end
