defmodule Bittorrent.CLI do
    def main(argv) do
        case argv do
            ["decode" | [encoded_str | _]] ->
                decoded_str = Bencode.decode(encoded_str)
                IO.puts(Jason.encode!(decoded_str))
            [command | _] ->
                IO.puts("Unknown command: #{command}")
                System.halt(1)
            [] ->
                IO.puts("Usage: your_bittorrent.sh <command> <args>")
                System.halt(1)
        end
    end
end

defmodule Bencode do
    def decode(encoded_value) when is_binary(encoded_value) do
        case parse(:binary.bin_to_list(encoded_value), {nil, []}, []) do
          [{:list, list}] -> list
          [{:dict, dict}] -> dict
          [item]          -> item
          _               -> raise("there should be a singular root item")
        end
    end
    def decode(_), do: "Invalid encoded value: not binary"

    # base case when the full parsing is complete
    defp parse([], _, result), do: result

    # parse strings
    defp parse([digit | rest], {nil, []}, parsed) when ?0<=digit and digit<=?9, do: parse(rest, {:strlen, [digit]}, parsed)
    defp parse([digit | rest], {:strlen, len}, parsed) when ?0<=digit and digit<=?9, do: parse(rest, {:strlen, [digit | len]}, parsed)
    defp parse([?: | rest], {:strlen, len}, parsed) do
        strlen = Enum.reverse(len) |> List.to_integer()
        {word, rest} = {Enum.slice(rest, 0, strlen) |> List.to_string(), Enum.slice(rest, strlen..-1//1)}
        parsed = case parsed do
            [{type, curr} | prev] when is_list(curr) -> [{type, [word | curr]} | prev]
            _                                        -> [ word | parsed ]
        end
        parse(rest, {nil, []}, parsed)
    end

    # parse integers
    defp parse([?i | rest], {nil, []}, parsed), do: parse(rest, {:integer, []}, parsed)
    defp parse([?- | rest], {:integer, []}, parsed), do: parse(rest, {:integer, [?-]}, parsed)
    defp parse([digit | rest], {:integer, rev_int}, parsed) when ?0<=digit and digit<=?9, do: parse(rest, {:integer, [digit | rev_int]}, parsed)
    defp parse([?e | rest], {:integer, rev_int}, parsed) do
        integer = Enum.reverse(rev_int) |> List.to_integer()
        parsed = case parsed do
            [{type, curr} | prev] when is_list(curr) -> [{type, [integer | curr]} | prev]
            _                                        -> [integer | parsed]
        end
        parse(rest, {nil, []}, parsed)
    end

    # parse lists
    defp parse([?l | rest], {nil, []}, parsed), do: parse(rest, {nil, []}, [{:list, []} | parsed])
    defp parse([?e | rest], _, [{:list, list} | prev]) do
        list = Enum.reverse(list)
        parsed = case prev do
            [{type, curr} | pprev] when is_list(curr) -> [{type, [list | curr]} | pprev]
            []                                        -> [list | prev]
        end
        parse(rest, {nil, []}, parsed)
    end

    # parse dictionaries
    defp parse([?d | rest], {nil, []}, parsed), do: parse(rest, {nil, []}, [{:dict, []} | parsed])
    defp parse([?e | rest], _, [{:dict, dict} | prev]) do
        dict = Enum.reverse(dict) |> Enum.chunk_every(2) |> Map.new(fn [k, v] -> {k, v} end)
        parsed = case prev do
            [{type, curr} | pprev] when is_list(curr) -> [{type, [dict | curr]} | pprev]
            []                                        -> [dict | prev]
        end
        parse(rest, {nil, []}, parsed)
    end
end
