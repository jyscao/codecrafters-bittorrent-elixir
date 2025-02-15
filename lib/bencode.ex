defmodule Bencode do
  def decode_file(torrent_file), do:
    (with {:ok, benc_str} <- File.read(torrent_file), do: decode(benc_str), else: (err -> err))

  def decode(benc_str) when is_binary(benc_str), do: parse(:binary.bin_to_list(benc_str), [])
  def decode(_), do: "Invalid encoded value: not binary"

  # parsing completed
  defp parse([], [{_type, decoded}]), do: decoded

  # parse integers (NOTE: integers must be handled before strings, otherwise decimal digits could be mistaken as string lengths)
  defp parse([?i | rest], parsed), do: parse(rest, [{:int, []} | parsed])
  defp parse([digit | rest], [{:int, digs_rev} | outers]) when ?0<=digit and digit<=?9 or digit===?-, do:
    parse(rest, [{:int, [digit | digs_rev]} | outers])
  defp parse([?e | rest], [{:int, digs_rev} | outers]) do
    integer = Enum.reverse(digs_rev) |> List.to_integer()
    parsed = case outers do
      []                                         -> [{:int, integer}]
      [{type, curr} | outers] when is_list(curr) -> [{type, [{:int, integer} | curr]} | outers]
    end
    parse(rest, parsed)
  end

  # parse strings
  defp parse([digit | rest], parsed) when ?0<=digit and digit<=?9 do
    parsed = case parsed do
      [{:strlen, slen_rev} | outers] -> [{:strlen, [digit | slen_rev]} | outers]
      _                              -> [{:strlen, [digit]} | parsed]
    end
    parse(rest, parsed)
  end
  defp parse([?: | rest], [{:strlen, slen_rev} | outers]) do
    slen = Enum.reverse(slen_rev) |> List.to_integer()
    word = Enum.slice(rest, 0, slen) |> List.to_string()
    rest = Enum.slice(rest, slen..-1//1)
    parsed = case outers do
      []                                         -> [{:str, word}]
      [{type, curr} | outers] when is_list(curr) -> [{type, [{:str, word} | curr]} | outers]
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
    dict = Stream.chunk_every(dict, 2) |> Map.new(fn [{_t, val}, {:str, key}] -> {key, val} end)
    parsed = case outers do
      []                                         -> [{:dict, dict}]
      [{type, curr} | outers] when is_list(curr) -> [{type, [{:dict, dict} | curr]} | outers]
    end
    parse(rest, parsed)
  end
end
