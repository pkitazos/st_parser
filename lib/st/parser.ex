defmodule ST.Parser do
  import NimbleParsec

  # Identifiers
  identifier =
    ascii_char([?A..?Z, ?a..?z, ?_])
    |> repeat(ascii_char([?A..?Z, ?a..?z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})
    |> map({Macro, :underscore, []})
    |> map({String, :to_atom, []})

  # Basic types
  string_type = string("string") |> replace(:binary)
  number_type = string("number") |> replace(:number)
  unit_type = string("unit") |> replace(:unit)
  boolean_type = string("boolean") |> replace(:boolean)

  # Basic payload type - matches one of the basic types
  basic_payload_type =
    choice([
      string_type,
      number_type,
      unit_type,
      boolean_type
    ])

  # List type (e.g., string[], number[])
  list_type =
    basic_payload_type
    |> ignore(string("[]"))
    |> map({__MODULE__, :wrap_list_type, []})

  # Whitespace parser - matches space, tab, newline
  whitespace =
    ascii_char([?\s, ?\t, ?\n, ?\r])
    |> repeat()
    |> ignore()

  # End terminal
  end_type =
    string("end")
    |> replace(%ST.SEnd{})

  # First define all the private parsers we'll need
  defcombinatorp(
    :payload_type_inner,
    choice([
      parsec(:tuple_inner),
      list_type,
      basic_payload_type
    ])
  )

  defcombinatorp(
    :tuple_inner,
    ignore(string("("))
    |> concat(whitespace)
    |> concat(parsec(:payload_type_inner))
    |> repeat(
      ignore(string(","))
      |> concat(whitespace)
      |> concat(parsec(:payload_type_inner))
    )
    |> repeat(
      # a bit silly but it works
      ignore(string(" ,"))
      |> concat(whitespace)
      |> concat(parsec(:payload_type_inner))
    )
    |> concat(whitespace)
    |> ignore(string(")"))
    |> post_traverse({__MODULE__, :wrap_tuple_type, []})
  )

  # Define a branch parser without using the continuation parser yet
  defcombinatorp(
    :branch_without_cont,
    # Label
    identifier
    |> ignore(string("("))
    |> concat(whitespace)
    # PayloadType
    |> concat(parsec(:payload_type_inner))
    |> concat(whitespace)
    |> ignore(string(")"))
    # Period separator
    |> ignore(string("."))
  )

  # Branch list (comma-separated branches)
  defcombinatorp(
    :branch_list_inner,
    parsec(:branch)
    |> repeat(
      ignore(string(","))
      |> concat(whitespace)
      |> concat(parsec(:branch))
    )
  )

  # Input type without finishing the branch parsing yet
  defcombinatorp(
    :input_inner,
    ignore(string("&"))
    # Role
    |> concat(identifier)
    |> ignore(string(":"))
    |> ignore(string("{"))
    |> concat(whitespace)
    # Branches
    |> concat(parsec(:branch_list))
    |> concat(whitespace)
    |> ignore(string("}"))
    |> post_traverse({__MODULE__, :wrap_input, []})
  )

  # Output type without finishing the branch parsing yet
  defcombinatorp(
    :output_inner,
    ignore(string("+"))
    # Role
    |> concat(identifier)
    |> ignore(string(":"))
    |> ignore(string("{"))
    |> concat(whitespace)
    # Branches
    |> concat(parsec(:branch_list))
    |> concat(whitespace)
    |> ignore(string("}"))
    |> post_traverse({__MODULE__, :wrap_output, []})
  )

  # Define session type which includes end, input and output
  defcombinatorp(
    :session_type_inner,
    choice([
      end_type,
      parsec(:input),
      parsec(:output)
    ])
  )

  # Now define the full branch with continuation
  defcombinatorp(
    :branch,
    parsec(:branch_without_cont)
    |> concat(parsec(:session_type))
    |> post_traverse({__MODULE__, :wrap_branch, []})
  )

  # Define the exported parsers
  defparsecp(:branch_list, parsec(:branch_list_inner))
  defparsecp(:input, parsec(:input_inner))
  defparsecp(:output, parsec(:output_inner))
  defparsecp(:session_type, parsec(:session_type_inner))

  # Helper functions
  def wrap_list_type(type) do
    {:list, [type]}
  end

  def wrap_tuple_type(rest, args, context, _line, _offset) do
    # Fix the order of elements (they come in reverse)
    types = Enum.reverse(args)
    {rest, [{:tuple, types}], context}
  end

  def wrap_branch(rest, [session_type, payload_type, label], context, _line, _offset) do
    branch = %ST.SBranch{
      label: label,
      payload: payload_type,
      continue_as: session_type
    }

    {rest, [branch], context}
  end

  def wrap_input(rest, branches_and_role, context, _line, _offset) do
    # Last element is the role, everything else are branches
    {branches, [role]} = Enum.split(branches_and_role, length(branches_and_role) - 1)

    input = %ST.SIn{
      from: role,
      branches: branches
    }

    {rest, [input], context}
  end

  def wrap_output(rest, branches_and_role, context, _line, _offset) do
    # Last element is the role, everything else are branches
    {branches, [role]} = Enum.split(branches_and_role, length(branches_and_role) - 1)

    output = %ST.SOut{
      to: role,
      branches: branches
    }

    {rest, [output], context}
  end

  # Export the parsers
  defparsec(:parse_session_type, parsec(:session_type))
  defparsec(:parse_branch, parsec(:branch))
  defparsec(:parse_input, parsec(:input))
  defparsec(:parse_output, parsec(:output))
  defparsec(:payload_type, parsec(:payload_type_inner))
  defparsec(:parse_tuple, parsec(:tuple_inner))
  defparsec(:parse_identifier, identifier)
  defparsec(:parse_basic_type, basic_payload_type)
  defparsec(:parse_end, end_type)
end
