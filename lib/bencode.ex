defmodule Bencode do
    def get_info_hash(encoded_value) when is_binary(encoded_value) do
        :binary.bin_to_list(encoded_value)
        |> find_info_start()
        |> find_info_content(0, [])
        |> then(&(:crypto.hash(:sha, &1)))
        |> Base.encode16(case: :lower)
    end
    def get_info_hash(_), do: "Invalid encoded value: not binary"

    defp find_info_start(~c"4:info" ++ rest), do: rest
    defp find_info_start([_ | rest]), do: find_info_start(rest)

    defp find_info_content([?e | _rest], 1, res), do: Enum.reverse([?e | res])
    defp find_info_content([?e | rest], lvl, res), do: find_info_content(rest, lvl-1, [?e | res])
    defp find_info_content([?: | rest], lvl, res) do
        strlen = Enum.find_index(res, &(&1 not in ~c"0123456789"))
            |> then(&(Enum.slice(res, 0, &1)))
            |> Enum.reverse()
            |> List.to_integer()
        {wrev, rest} = {Enum.slice(rest, 0, strlen) |> Enum.reverse(), Enum.slice(rest, strlen..-1//1)}
        find_info_content(rest, lvl, wrev ++ [?: | res])
    end
    defp find_info_content([init | rest], lvl, res) when init in [?i, ?l, ?d], do: find_info_content(rest, lvl+1, [init | res])
    defp find_info_content([char | rest], lvl, res), do: find_info_content(rest, lvl, [char | res])

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
            [] -> [{:dict, dict}]
            [{type, curr} | outers] when is_list(curr) -> [{type, [{:dict, dict} | curr]} | outers]
        end
        parse(rest, parsed)
    end
end
