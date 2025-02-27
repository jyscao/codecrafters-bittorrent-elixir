defmodule MagnetLink do
  alias Bittorrent.Peer.Worker

  @self_peer_id :crypto.hash(:sha, "jyscao")

  def parse("magnet:?" <> params) do
    URI.query_decoder(params)
    |> Enum.map(fn {key, val} ->
      case key do
        "xt" -> "urn:btih:" <> info_hash = val; {:xt, info_hash}
        "tr" -> {:tr, val}
        _    -> nil
      end
    end)
    |> Enum.filter(&(&1))
  end

  def parse(_link), do: raise("invalid magnet link")

  def shake_hand_and_get_peer_id(link) do
    with params = MagnetLink.parse(link),
      tracker_url = params[:tr],
      info_hash = :binary.decode_hex(params[:xt]),
      peer = get_peers_from_tracker(tracker_url, info_hash) |> hd(),
      {:ok, pid} = Worker.start(info_hash, peer),
      {metadata_ext?, peer_id_int} = Worker.do_magnet_handshake(pid)
    do
      if metadata_ext? do
        with ext_dict = Worker.do_extension_handshake(pid) do
          %{"m" => %{"ut_metadata" => peer_ext_id}} = Bencode.decode(ext_dict) # |> IO.inspect(label: "extension dict")
          {:ok, {:binary.encode_unsigned(peer_id_int) |> Base.encode16(case: :lower), peer_ext_id}}
        end
      else
        {:ok, {:binary.encode_unsigned(peer_id_int) |> Base.encode16(case: :lower), nil}}
      end
    end
  end

  def get_peers_from_tracker(tracker_url, info_hash) do
    query_params = [
      info_hash:  info_hash,
      peer_id:    @self_peer_id,
      port:       6881,
      uploaded:   0,
      downloaded: 0,
      left:       9999,   # NOTE: comment from challenge author - The tracker will require a "left" parameter value greater than zero, but we don't know file size in advance. You can send a made up value like 999 as a workaround
      compact:    1
    ]

    case Req.get(tracker_url, params: query_params) do
      {:ok, resp} -> resp.body |> get_peer_addrs_ls()
      {:error, e} -> e
    end
  end

  defp get_peer_addrs_ls(tracker_resp) do
    Bencode.decode(tracker_resp)
    |> Map.fetch!("peers")
    |> String.to_charlist()
    |> :binary.list_to_bin()
    |> extract_peer_addrs([])
  end

  defp extract_peer_addrs(<<>>, addrs), do: addrs
  defp extract_peer_addrs(<<a, b, c, d, port::16, rest::binary>>, addrs), do:
    extract_peer_addrs(rest, [{{a, b, c, d}, port}| addrs])
end
