defmodule Bittorrent.Peer.TcpMessage do
  @block_length 16*1024  # 16 KiB

  # @msg_choke        0
  @msg_unchoke      1
  @msg_interested   2
  # @msg_uninterested 3
  # @msg_have         4
  @msg_bitfield     5
  @msg_request      6
  @msg_piece        7
  # @msg_cancel       8

  def connect({{_a,_b,_c,_d} = ipv4, port}) do
    case :gen_tcp.connect(ipv4, port, [:binary, active: false]) do
      {:ok, socket} -> {:ok, socket}
      err           -> err
    end
  end

  def do_handshake(socket, info_hash, self_peer_id) do
    with :ok <- :gen_tcp.send(socket, mk_handshake_msg(info_hash, self_peer_id)),
      {:ok, resp} <- :gen_tcp.recv(socket, 0)
    do
      {:ok, resp}
    else
      err -> err
    end
  end

  defp mk_handshake_msg(info_hash, self_peer_id), do:
    <<19>> <> "BitTorrent protocol" <> <<0::64>> <> info_hash <> self_peer_id

  def pre_download_chitchat(socket) do
    with {:ok, _bf_resp} = get_bitfield(socket),
      :ok = inform_interest(socket),
      :ok = receive_unchoke(socket)
    do
      :ok
    end
  end

  defp get_bitfield(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, <<_msg_len::32, @msg_bitfield, _bitfields::binary>> = bf_resp}
        -> {:ok, bf_resp}

      e -> e
    end
  end

  defp inform_interest(socket), do:
    :ok = :gen_tcp.send(socket, <<0, 0, 0, 1, @msg_interested>>)

  # TODO: keep receiving until the unchoke message is gotten; ignore messages such as @msg_have
  defp receive_unchoke(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, <<0, 0, 0, 1, @msg_unchoke>>}
        -> :ok

      e -> e
    end
  end

  def req_then_recv_block(socket, {pidx, bidx, curr_blen}) do
    req_payload = <<@msg_request>> <> ext_32b(pidx) <> ext_32b(bidx * @block_length) <> ext_32b(curr_blen)
    req_msg = ext_32b(bit_size(req_payload)) <> req_payload
    with :ok = :gen_tcp.send(socket, req_msg),
      {:ok, <<payload_len::32, @msg_piece, _pidx::32, _begin::32, init_chunk::binary>>} = :gen_tcp.recv(socket, 0)
    do
      bytes_left = payload_len - 9 - div(bit_size(init_chunk), 8)
      recv_block_chunks(socket, bytes_left, [init_chunk]) |> Enum.reverse() |> Enum.join()
    end
  end

  defp ext_32b(val) do
    bin = :binary.encode_unsigned(val)
    <<0::size(32 - bit_size(bin))>> <> bin
  end

  defp recv_block_chunks(_socket, 0, received), do: received
  defp recv_block_chunks(socket, bytes_left, received) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, chunk} ->
        n_bytes = div(bit_size(chunk), 8)
        recv_block_chunks(socket, bytes_left - n_bytes, [chunk | received])

      err -> err
    end
  end
end
