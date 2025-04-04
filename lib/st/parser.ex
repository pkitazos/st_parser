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

  # Forward declare payload_type for recursion
  defcombinatorp(:payload_type_recursive, parsec(:payload_type_inner))

  # Tuple type implementation with better whitespace handling
  defcombinatorp(
    :tuple_inner,
    ignore(string("("))
    |> concat(whitespace)
    |> concat(parsec(:payload_type_recursive))
    |> repeat(
      ignore(string(","))
      |> concat(whitespace)
      |> concat(parsec(:payload_type_recursive))
    )
    |> concat(whitespace)
    |> ignore(string(")"))
    |> post_traverse({__MODULE__, :wrap_tuple_type, []})
  )

  # Combined payload type (either tuple, list, or basic)
  defcombinatorp(
    :payload_type_inner,
    choice([
      parsec(:tuple_inner),
      list_type,
      basic_payload_type
    ])
  )

  # End terminal
  end_type =
    string("end")
    |> replace(%ST.SEnd{})

  # Helper functions
  def wrap_list_type(type) do
    {:list, [type]}
  end

  def wrap_tuple_type(rest, args, context, _line, _offset) do
    # Fix the order of elements (they come in reverse)
    types = Enum.reverse(args)
    {rest, [{:tuple, types}], context}
  end

  # Export the parsers
  defparsec(:payload_type, parsec(:payload_type_inner))
  defparsec(:parse_tuple, parsec(:tuple_inner))
  defparsec(:parse_identifier, identifier)
  defparsec(:parse_basic_type, basic_payload_type)
  defparsec(:parse_end, end_type)
end
