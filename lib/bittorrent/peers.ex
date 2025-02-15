defmodule Peers do
  @self_peer_id :crypto.hash(:sha, "jyscao")

  def get(encoded_str) do
    encoded_str
    |> make_tracker_request()
    |> Bencode.decode()
    |> Map.fetch!("peers")
    |> String.to_charlist()
    |> :binary.list_to_bin()
    |> extract_peer_addrs([])
  end

  defp make_tracker_request(encoded_str) do
    %{
      "announce" => tracker_url,
      "info"     => %{"length" => file_size}
    } = Bencode.decode(encoded_str)

    query_params = [
      info_hash:  Metainfo.get_info_hash_raw(encoded_str),
      peer_id:    @self_peer_id,
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

  defp extract_peer_addrs(<<>>, addrs), do: addrs
  defp extract_peer_addrs(<<a, b, c, d, port::16, rest::binary>>, addrs), do:
    extract_peer_addrs(rest, ["#{a}.#{b}.#{c}.#{d}:#{port}" | addrs])
end
