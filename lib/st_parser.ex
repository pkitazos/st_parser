defmodule ST.Parser do
  @moduledoc """
  User-friendly API for the Session Type Parser.

  This module provides convenient functions for parsing session type expressions
  into their corresponding ST data structures. It serves as the main entry point
  for using the parser in application code.
  """

  @doc """
  Parses a complete session type expression.

  Returns `{:ok, parsed_type}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> ST.Parser.parse("&Server:{ Ack(unit).end }")
      {:ok, %ST.SIn{
        from: :server,
        branches: [
          %ST.SBranch{
            label: :ack,
            payload: :unit,
            continue_as: %ST.SEnd{}
          }
        ]
      }}

      iex> ST.Parser.parse("+Client:{ Request(string).end }")
      {:ok, %ST.SOut{
        to: :client,
        branches: [
          %ST.SBranch{
            label: :request,
            payload: :binary,
            continue_as: %ST.SEnd{}
          }
        ]
      }}

      iex> ST.Parser.parse("end")
      {:ok, %ST.SEnd{}}
  """
  def parse(input) when is_binary(input) do
    case ST.Parser.Core.parse_session_type(input) do
      {:ok, [result], "", _, _, _} ->
        {:ok, result}

      {:ok, _, rest, _, _, _} ->
        {:error, "Could not parse entire input. Stopped at: #{inspect(rest)}"}

      {:error, reason, rest, _, _, _} ->
        {:error, "Parser error: #{inspect(reason)}. At: #{inspect(rest)}"}
    end
  end

  @doc """
  Parses a session type expression, raising an exception on failure.

  Returns the parsed type directly on success.

  ## Examples

      iex> ST.Parser.parse!("end")
      %ST.SEnd{}

      iex> ST.Parser.parse!("invalid")
      ** (RuntimeError) Parser error: ...
  """
  def parse!(input) when is_binary(input) do
    case parse(input) do
      {:ok, result} -> result
      {:error, reason} -> raise "Parse error: #{reason}"
    end
  end

  @doc """
  Parses a payload type expression.

  Returns `{:ok, parsed_type}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> ST.Parser.parse_type("string")
      {:ok, :binary}

      iex> ST.Parser.parse_type("boolean[]")
      {:ok, {:list, [:boolean]}}

      iex> ST.Parser.parse_type("(string, number)")
      {:ok, {:tuple, [:binary, :number]}}
  """
  def parse_type(input) when is_binary(input) do
    case ST.Parser.Core.payload_type(input) do
      {:ok, [result], "", _, _, _} ->
        {:ok, result}

      {:ok, _, rest, _, _, _} ->
        {:error, "Could not parse entire type. Stopped at: #{inspect(rest)}"}

      {:error, reason, rest, _, _, _} ->
        {:error, "Type parser error: #{inspect(reason)}. At: #{inspect(rest)}"}
    end
  end

  @doc """
  Parses a payload type expression, raising an exception on failure.

  Returns the parsed type directly on success.

  ## Examples

      iex> ST.Parser.parse_type!("string")
      :binary

      iex> ST.Parser.parse_type!("invalid_type")
      ** (RuntimeError) Type parser error: ...
  """
  def parse_type!(input) when is_binary(input) do
    case parse_type(input) do
      {:ok, result} -> result
      {:error, reason} -> raise "Type parse error: #{reason}"
    end
  end
end
