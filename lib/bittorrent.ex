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
        [{_type, item}] = parse(:binary.bin_to_list(encoded_value), [])
        item
    end
    def decode(_), do: "Invalid encoded value: not binary"

    # parsing completed
    defp parse([], parsed), do: parsed

    # parse integers
    defp parse([?i | rest], parsed), do: parse(rest, [{:integer, []} | parsed])
    # NOTE: integers need to be handled before strings, otherwise a decimal digit would be mistaken for a string length
    defp parse([digit | rest], [{:integer, idr} | outers]) when ?0<=digit and digit<=?9 or digit===?-, do:
        parse(rest, [{:integer, [digit | idr]} | outers])
    defp parse([?e | rest], [{:integer, idr} | outers]) do
        integer = Enum.reverse(idr) |> List.to_integer()
        parsed = case outers do
            []                                         -> [{:integer, integer}]
            [{type, curr} | outers] when is_list(curr) -> [{type, [{:integer, integer} | curr]} | outers]
        end
        parse(rest, parsed)
    end

    # parse strings
    defp parse([digit | rest], parsed) when ?0<=digit and digit<=?9 do
        parsed = case parsed do
          [{:strlen, slr} | outers] -> [{:strlen, [digit | slr]} | outers]
          _                         -> [{:strlen, [digit]} | parsed]
        end
        parse(rest, parsed)
    end
    defp parse([?: | rest], [{:strlen, slr} | outers]) do
        strlen = Enum.reverse(slr) |> List.to_integer()
        {word, rest} = {Enum.slice(rest, 0, strlen) |> List.to_string(), Enum.slice(rest, strlen..-1//1)}
        parsed = case outers do
            []                                         -> [{:string, word}]
            [{type, curr} | outers] when is_list(curr) -> [{type, [{:string, word} | curr]} | outers]
        end
        parse(rest, parsed)
    end

    # parse lists
    defp parse([?l | rest], parsed), do: parse(rest, [{:list, []} | parsed])
    defp parse([?e | rest], [{:list, list} | outers]) do
        list = Stream.map(list, fn {_t, val} -> val end) |> Enum.reverse()
        parsed = case outers do
            []                                         -> [{:list, list}]
            [{type, curr} | outers] when is_list(curr) -> [{type, [{:list, list} | curr]} | outers]
        end
        parse(rest, parsed)
    end

    # parse dictionaries
    defp parse([?d | rest], parsed), do: parse(rest, [{:dict, []} | parsed])
    defp parse([?e | rest], [{:dict, dict} | outers]) do
        dict = Stream.chunk_every(dict, 2) |> Map.new(fn [{_val_t, val}, {:string, key}] -> {key, val} end)
        parsed = case outers do
            []                                         -> [{:dict, dict}]
            [{type, curr} | outers] when is_list(curr) -> [{type, [{:dict, dict} | curr]} | outers]
        end
        parse(rest, parsed)
    end
end
