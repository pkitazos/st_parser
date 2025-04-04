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

  # Simple payload type (basic or list)
  simple_payload_type =
    choice([
      list_type,
      basic_payload_type
    ])

  # Optional whitespace
  optional_whitespace =
    optional(ascii_char([?\s, ?\t, ?\n, ?\r]) |> repeat())
    |> ignore()

  # Tuple type implementation using defcombinatorp
  defcombinatorp(
    :tuple_inner,
    string("(")
    |> concat(optional_whitespace)
    |> concat(parsec(:payload_type))
    |> repeat(
      string(",")
      |> concat(optional_whitespace)
      |> concat(parsec(:payload_type))
    )
    |> concat(optional_whitespace)
    |> string(")")
    |> post_traverse({__MODULE__, :wrap_tuple_type, []})
  )

  # Recursive definition of payload_type
  defcombinatorp(
    :payload_type_inner,
    choice([
      parsec(:tuple_inner),
      simple_payload_type
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
    # Extract the types from the args (excluding parentheses and commas)
    types =
      args
      |> Enum.filter(fn
        "(" -> false
        ")" -> false
        "," -> false
        _ -> true
      end)

    {rest, [{:tuple, types}], context}
  end

  # Export the parsers
  defparsec(:payload_type, parsec(:payload_type_inner))
  defparsec(:parse_tuple, parsec(:tuple_inner))
  defparsec(:parse_identifier, identifier)
  defparsec(:parse_basic_type, basic_payload_type)
  defparsec(:parse_end, end_type)
end
