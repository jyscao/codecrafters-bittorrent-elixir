defmodule Metainfo do
    def get_all(encoded_str) do
        %{
            "announce" => tracker_url,
            "info"     => %{
                "length"       => file_length,
                "piece length" => piece_length,
                "pieces"       => encoded_piece_hashes,
            },
        } = Bencode.decode(encoded_str)

        %{
            tracker_url: tracker_url,
            file_length: file_length,
            info_hash: get_info_hash(encoded_str),
            piece_length: piece_length,
            piece_hashes: String.to_charlist(encoded_piece_hashes) |> get_piece_hashes([])
        }
    end

    defp get_info_hash(encoded_value) when is_binary(encoded_value) do
        :binary.bin_to_list(encoded_value)
        |> find_info_start()
        |> find_info_content(0, [])
        |> then(&(:crypto.hash(:sha, &1)))
        |> Base.encode16(case: :lower)
    end
    defp get_info_hash(_), do: "Invalid encoded value: not binary"

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

    defp get_piece_hashes([], hashes), do:
        Enum.reverse(hashes) |> Enum.map_join(&((if String.length(&1)===1, do: "0#{&1}", else: &1) |> String.downcase()))
    defp get_piece_hashes([byte | rest], hashes), do:
        get_piece_hashes(rest, [Integer.to_string(byte, 16) | hashes])
end
