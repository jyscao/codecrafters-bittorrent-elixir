defmodule Bittorrent.Metainfo do
  import Shorthand

  def extract_from_file(torrent_file), do: Bencode.decode_file(torrent_file) |> get_all()

  def compute_info_hash(torrent_file, format \\ :base16) do
    with {:ok, benc_str} <- File.read(torrent_file),
      info_hash_raw <- find_and_compute_info_hash(benc_str)
    do
      case format do
        :base16 -> Base.encode16(info_hash_raw, case: :lower)
        :raw    -> info_hash_raw
        _       -> raise("unrecognized info hash format")
      end
    else
      err -> err
    end
  end

  def get_info_link_from_magnet_metadata(info_data) do
    %{
      "length"       => file_length,
      "piece length" => piece_length,
      "pieces"       => piece_hashes_utf8,
    } = info_data
    piece_hashes = String.to_charlist(piece_hashes_utf8) |> get_piece_hashes([])
    m(file_length, piece_length, piece_hashes)
  end

  defp get_all(decoded_data) do
    %{
      "announce" => tracker_url,
      "info"     => %{
        "length"       => file_length,
        "piece length" => piece_length,
        "pieces"       => piece_hashes_utf8,
      },
    } = decoded_data
    piece_hashes = String.to_charlist(piece_hashes_utf8) |> get_piece_hashes([])
    m(tracker_url, file_length, piece_length, piece_hashes)
  end

  defp find_and_compute_info_hash(benc_str) when is_binary(benc_str) do
    :binary.bin_to_list(benc_str)
    |> find_info_start()
    |> find_info_content(0, [])
    |> then(&(:crypto.hash(:sha, &1)))
  end

  defp find_info_start(~c"4:info" ++ rest), do: rest
  defp find_info_start([_ | rest]), do: find_info_start(rest)

  defp find_info_content([?e | _rest], 1, res), do: Enum.reverse([?e | res])
  defp find_info_content([?e | rest], lvl, res), do: find_info_content(rest, lvl-1, [?e | res])
  defp find_info_content([?: | rest], lvl, res) do
    slen = Enum.find_index(res, &(&1 not in ~c"0123456789"))
      |> then(&(Enum.slice(res, 0, &1)))
      |> Enum.reverse()
      |> List.to_integer()
    wrev = Enum.slice(rest, 0, slen) |> Enum.reverse()
    rest = Enum.slice(rest, slen..-1//1)
    find_info_content(rest, lvl, wrev ++ [?: | res])
  end
  defp find_info_content([init | rest], lvl, res) when init in [?i, ?l, ?d], do: find_info_content(rest, lvl+1, [init | res])
  defp find_info_content([char | rest], lvl, res), do: find_info_content(rest, lvl, [char | res])

  defp get_piece_hashes([], hashes) do
    Enum.reverse(hashes)
    |> Stream.chunk_every(20)
    |> Stream.map(&(Enum.join(&1)))
  end
  defp get_piece_hashes([byte | rest], hashes), do:
    get_piece_hashes(rest, [Integer.to_string(byte, 16) |> String.pad_leading(2, "0") |> String.downcase() | hashes])
end
