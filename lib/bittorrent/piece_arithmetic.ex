defmodule Bittorrent.PieceArithmetic do

  import Shorthand

  @block_length 16*1024  # 16 KiB

  def partition_pieces_from_file(torrent_file) do
    with metainfo <- Bittorrent.Metainfo.extract_from_file(torrent_file),
      m(file_length, piece_length) = metainfo,
      0 = rem(piece_length, @block_length),   # ensure piece-length divides block-length
      {n_pieces, lp_size} = calc_pieces_count_and_lp_size(file_length, piece_length)
    do
      0..n_pieces-1 |> Enum.map(&({&1, get_blocks_range_and_lb_size(&1, piece_length, n_pieces, lp_size)}))
    end
  end

  defp calc_pieces_count_and_lp_size(file_length, piece_length) do
    n_pieces  = div(file_length, piece_length)
    rem_bytes = rem(file_length, piece_length)
    if rem_bytes===0, do: {n_pieces, piece_length}, else: {n_pieces+1, rem_bytes}
  end

  defp get_blocks_range_and_lb_size(pidx, piece_length, n_pieces, lp_size) do
    {n_blocks, lb_size} = if pidx === n_pieces-1 do
      calc_last_piece_blocks_count_and_lb_size(lp_size)
    else
      {div(piece_length, @block_length), @block_length}
    end
  end

  defp calc_last_piece_blocks_count_and_lb_size(lp_size) do
    if lp_size <= @block_length do
      {0, lp_size}
    else
      n_blocks  = div(lp_size, @block_length)
      rem_bytes = rem(lp_size, @block_length)
      if rem_bytes===0, do: {n_blocks, @block_length}, else: {n_blocks+1, rem_bytes}
    end
  end
end
