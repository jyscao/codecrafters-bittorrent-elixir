defmodule Bittorrent.Download do

  alias Bittorrent.{Metainfo, Peer, Peer.Worker, PieceArithmetic}

  @block_length 16*1024   # 16 KiB

  def download_piece(torrent_file, piece_idx, output_location) do
    with workers = ready_workers(torrent_file),
      blocks = divide_pieces_into_blocks(torrent_file, piece_idx),
      %{piece_hashes: hashes} = Metainfo.extract_from_file(torrent_file)
    do
      piece_data = Stream.chunk_every(blocks, length(workers))
        |> Stream.flat_map(
          &(Enum.zip(workers, &1)
            |> Enum.map(fn {pid, blk} -> Task.async(Worker, :download_block, [pid, blk]) end)
            |> Enum.map(fn task -> Task.await(task) end)
          ))
        |> Enum.join()

      with true = verify_piece(hashes, piece_idx, piece_data) do
        File.write!(output_location, piece_data)
      end
    end
  end

  def download_all(torrent_file, output_location) do
    with workers = ready_workers(torrent_file),
      blocks = divide_pieces_into_blocks(torrent_file),
      %{piece_hashes: hashes} = Metainfo.extract_from_file(torrent_file)
    do
      pieces_map = Stream.chunk_every(blocks, length(workers))
        |> Stream.flat_map(
          &(Enum.zip(workers, &1)
            |> Enum.map(fn {pid, {pce, _, _} = blk_tup} -> {pce, Task.async(Worker, :download_block, [pid, blk_tup])} end)
            |> Enum.map(fn {pce, task} -> {pce, Task.await(task)} end)
          ))
        |> Enum.group_by(fn {pce, _} -> pce end, fn {_, blocks} -> blocks end)
        |> Map.new(fn {pce, blocks} -> {pce, Enum.join(blocks)} end)

      with piece_statuses = Enum.map(pieces_map, fn {idx, data} -> verify_piece(hashes, idx, data) end),
        ^piece_statuses = List.duplicate(true, map_size(pieces_map))
      do
        Enum.sort_by(pieces_map, fn {idx, _} -> idx end)
        |> Enum.reduce(<<>>, fn {_, data}, acc -> acc <> data end)
        |> then(&(File.write!(output_location, &1)))
      end
    end
  end

  defp ready_workers(torrent_file) do
    with info_hash <- Metainfo.compute_info_hash(torrent_file, :raw),
      peer_addrs <- Peer.get_all_using_file(torrent_file),
      workers = Enum.map(peer_addrs, &(Worker.start(info_hash, &1))) |> Enum.map(fn {:ok, pid} -> pid end),
      worker_statuses = Enum.map(workers, &(Worker.do_handshake(&1) && Worker.inform_interest(&1))),
      ^worker_statuses = List.duplicate(true, length(workers))
    do
      workers
    end
  end

  defp divide_pieces_into_blocks(torrent_file, piece_idx \\ nil) do
    pieces = PieceArithmetic.partition_pieces_from_file(torrent_file)
    case piece_idx do
      nil -> Enum.flat_map(pieces, &(partition_piece(&1)))
      _   -> partition_piece(Enum.at(pieces, piece_idx))
    end
  end

  defp partition_piece({p, {nb, lb_sz}}) do
    Enum.map(0..nb-1, &(if &1 === nb-1, do: {p, &1, lb_sz}, else: {p, &1, @block_length}))
  end

  defp verify_piece(hashes, idx, data) do
    ph = Enum.at(hashes, idx)
    ^ph = :crypto.hash(:sha, data) |> Base.encode16(case: :lower)
    true
  end
end
