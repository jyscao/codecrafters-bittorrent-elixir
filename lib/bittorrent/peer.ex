defmodule Bittorrent.Peer do
  import Shorthand
  alias Bittorrent.{Metainfo, Peer.Worker}

  @self_peer_id :crypto.hash(:sha, "jyscao")

  def get_all_using_file(torrent_file) do
    with %{} = metainfo <- Metainfo.extract_from_file(torrent_file),
      info_hash <- Metainfo.compute_info_hash(torrent_file, :raw)
    do
      get_peer_addrs_ls(metainfo, info_hash)
    else
      err -> err
    end
  end

  defp get_peer_addrs_ls(%{} = metainfo, info_hash) do
    make_tracker_request(metainfo, info_hash)
    |> Bencode.decode()
    |> Map.fetch!("peers")
    |> String.to_charlist()
    |> :binary.list_to_bin()
    |> extract_peer_addrs([])
  end

  defp make_tracker_request(m(tracker_url, file_length), info_hash) do
    query_params = [
      info_hash:  info_hash,
      peer_id:    @self_peer_id,
      port:       6881,
      uploaded:   0,
      downloaded: 0,
      left:       file_length,
      compact:    1
    ]

    case Req.get(tracker_url, params: query_params) do
      {:ok, resp} -> resp.body
      {:error, e} -> e
    end
  end

  defp extract_peer_addrs(<<>>, addrs), do: addrs
  defp extract_peer_addrs(<<a, b, c, d, port::16, rest::binary>>, addrs), do:
    extract_peer_addrs(rest, [{{a, b, c, d}, port}| addrs])

  def shake_hand_and_get_peer_id(torrent_file, peer_addr) do
    with info_hash <- Metainfo.compute_info_hash(torrent_file, :raw),
      {:ok, pid} <- Worker.start(info_hash, peer_addr),
      peer_id_int = Worker.do_handshake(pid)
    do
      {:ok, :binary.encode_unsigned(peer_id_int) |> Base.encode16(case: :lower)}
    else
      err -> err
    end
  end
end
