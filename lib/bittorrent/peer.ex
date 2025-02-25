defmodule Bittorrent.Peer do
  import Shorthand
  alias Bittorrent.{Metainfo, Peer.TcpMessage}

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
      {:ok, socket} <- TcpMessage.connect(peer_addr),
      {:ok, hs_resp} <- TcpMessage.do_handshake(socket, info_hash, @self_peer_id)
    do
      extract_peer_id(hs_resp, info_hash)
    else
      err -> err
    end
  end

  # NOTE: some peers responds to the handshake w/ an extra 6-bytes of data after the 20-bytes
  #       ID (at least some of CodeCrafters' peers); thus ignore the rest w/ the _rest binary
  defp extract_peer_id(<<header_int::160, _ext_bytes::64, hash_int::160, pid_int::160, _rest::binary>>, info_hash) do
    with <<19>> <> "BitTorrent protocol" = :binary.encode_unsigned(header_int),
      ^info_hash = :binary.encode_unsigned(hash_int)
    do
      {:ok, :binary.encode_unsigned(pid_int) |> Base.encode16(case: :lower)}
    end
  end


  def prime_all_to_download(torrent_file) do
    with %{} = metainfo <- Metainfo.extract_from_file(torrent_file),
      info_hash = Metainfo.compute_info_hash(torrent_file, :raw),
      peer_addrs = get_peer_addrs_ls(metainfo, info_hash),
      dl_primer = mk_download_primer(info_hash)
    do
      {:ok, Enum.map(peer_addrs, dl_primer)}
    end
  end

  defp mk_download_primer(info_hash) do
    fn peer_addr ->
      with {:ok, socket} <- TcpMessage.connect(peer_addr),
        {:ok, _resp} <- TcpMessage.do_handshake(socket, info_hash, @self_peer_id),
        :ok <- TcpMessage.pre_download_chitchat(socket)
      do
        socket
      else
        err -> err
      end
    end
  end
end
