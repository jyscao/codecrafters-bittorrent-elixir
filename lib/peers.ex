defmodule Peers do
    def get(encoded_str) do
        %{"peers" => peers} = make_request(encoded_str) |> Bencode.decode()
        raw_peers_data = String.to_charlist(peers)
        decode_peer_ips(raw_peers_data, [])
    end

    defp make_request(encoded_str) do
        %{"announce" => tracker_url, "info" => %{"length" => file_size}} = Bencode.decode(encoded_str)

        query_params = [
            info_hash:  Metainfo.get_info_hash_raw(encoded_str),
            peer_id:    :crypto.hash(:sha, "jyscao"),
            port:       6881,
            uploaded:   0,
            downloaded: 0,
            left:       file_size,
            compact:    1
        ]

        case Req.get(tracker_url, params: query_params) do
            {:ok, resp} -> resp.body
            {:error, e} -> e
        end
    end

    defp decode_peer_ips([], ips), do: ips
    defp decode_peer_ips([a, b, c, d, p1, p2 | rest], ips) do
        port = get_binary_byte(p1) <> get_binary_byte(p2) |> String.to_integer(2)
        ip = "#{a}.#{b}.#{c}.#{d}:#{port}"
        decode_peer_ips(rest, [ip | ips])
    end

    defp get_binary_byte(num), do: Integer.to_string(num, 2) |> String.pad_leading(8, "0")
end
