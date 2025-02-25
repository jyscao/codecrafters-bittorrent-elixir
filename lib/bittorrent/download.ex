defmodule Bittorrent.Download do

  alias Bittorrent.{Metainfo, Peer, Peer.TcpMessage, PieceArithmetic}

  @block_length 16*1024   # 16 KiB

  def download_piece(torrent_file, pidx, output_location) do
    divide_work_amongst_peers(torrent_file) |> IO.inspect(label: "divided works")
    |> Enum.at(pidx)
    |> Enum.map(fn {sock, blk_tup} -> TcpMessage.req_then_recv_block(sock, blk_tup) end)
    |> Enum.join()
    |> then(&(File.write!(output_location, &1)))
  end

  defp divide_work_amongst_peers(torrent_file) do
    with %{} = metainfo <- Metainfo.extract_from_file(torrent_file),
      info_hash <- Metainfo.compute_info_hash(torrent_file, :raw),

      {:ok, peer_sockets} = Peer.prime_all_to_download(torrent_file),
      p = length(peer_sockets),
      peer_map = Stream.with_index(peer_sockets) |> Map.new(fn {ps, idx} -> {idx, ps} end),
      pieces = PieceArithmetic.partition_pieces_from_file(torrent_file)
    do
      q = length(pieces)
      Enum.map(pieces, fn {pidx, {n_blocks, lb_size}} ->
        Enum.map(0..n_blocks-1, &({peer_map[rem(pidx, p)], {pidx, &1, (if pidx===q-1 and &1===n_blocks-1, do: lb_size, else: @block_length)}}))
      end)
    end
  end
end
