defmodule Message do
    @block_len 16*1024

    def prepare_piece_download(encoded_str) do
        with {:ok, socket} = get_connected_peer_socket(encoded_str),
            {:ok, _bf_resp} = get_bitfield(socket),
            :ok = inform_interest(socket),
            :ok = receive_unchoke(socket)
        do
            {:ok, socket}
        end
    end

    def download_verify_and_save_piece!(encoded_str, socket, pidx, save_location) do
        %{
            file_length: file_length,
            piece_length: piece_length,
            piece_hashes: piece_hashes,
        } = Metainfo.get_all(encoded_str)

        pidx_hash = Enum.at(piece_hashes, pidx)
        with {:ok, piece} = download_piece(file_length, piece_length, socket, pidx),
            ^pidx_hash = :crypto.hash(:sha, piece) |> Base.encode16(case: :lower)
        do
            File.write!(save_location, piece)
        end
    end

    defp get_connected_peer_socket(encoded_str) do
        with peer_addr0 = Peers.get(encoded_str) |> hd(),
            {:ok, socket} = Handshake.get_peer_socket(peer_addr0),
            <<_peer_id_b16::320>> = Handshake.get_peer_id({:ok, socket}, encoded_str)
        do
            {:ok, socket}
        end
    end

    defp get_bitfield(socket) do
        case :gen_tcp.recv(socket, 0) do
            {:ok, <<_msg_len::32, 5, _bitfields::binary>> = bf_resp} -> {:ok, bf_resp}
            err            -> err
        end
    end

    defp inform_interest(socket), do: :ok = :gen_tcp.send(socket, <<0, 0, 0, 1, 2>>)

    defp receive_unchoke(socket) do
      case :gen_tcp.recv(socket, 0) do
            {:ok, <<0, 0, 0, 1, 1>>} -> :ok
            err            -> err
      end
    end

    defp download_piece(file_length, piece_length, socket, pidx) do
        if rem(piece_length, @block_len)!==0, do:
            raise("piece-length (#{div(piece_length, 1024)}kb) not divisible by block-length of 16kb")

        {n_blocks, lb_size} = get_blocks_count_and_lb_size(pidx, file_length, piece_length)

        piece = 0..n_blocks-1
        |> Enum.map(
            &(
                (if &1===n_blocks-1, do: lb_size, else: @block_len)
                |> then(fn blen -> send_block_request(socket, pidx, &1, blen) end)
            ))
        |> Enum.join()

        {:ok, piece}
    end

    defp get_blocks_count_and_lb_size(pidx, file_length, piece_length) do
        {n_pieces, lp_size} = calc_pieces_count_and_lp_size(file_length, piece_length)
        if pidx === n_pieces-1 do
            calc_last_piece_blocks_count_and_lb_size(lp_size)
        else
            {div(piece_length, @block_len), @block_len}
        end
    end

    defp calc_pieces_count_and_lp_size(file_length, piece_length) do
        n_pieces  = div(file_length, piece_length)
        rem_bytes = rem(file_length, piece_length)
        if rem_bytes===0, do: {n_pieces, piece_length}, else: {n_pieces+1, rem_bytes}
    end

    defp calc_last_piece_blocks_count_and_lb_size(lp_size) do
        if lp_size <= @block_len do
            {0, lp_size}
        else
            n_blocks  = div(lp_size, @block_len)
            rem_bytes = rem(lp_size, @block_len)
            if rem_bytes===0, do: {n_blocks, @block_len}, else: {n_blocks+1, rem_bytes}
        end
    end

    defp send_block_request(socket, pidx, bidx, block_len) do
        req_payload = <<6>> <> ext_32b(pidx) <> ext_32b(bidx * @block_len) <> ext_32b(block_len)
        req_msg = ext_32b(bit_size(req_payload)) <> req_payload
        with :ok = :gen_tcp.send(socket, req_msg),
            {:ok, <<payload_len::32, 7, _pidx::32, _begin::32, init_chunk::binary>>} = :gen_tcp.recv(socket, 0)
        do
            bytes_left = payload_len - 9 - div(bit_size(init_chunk), 8)
            receive_block(socket, bytes_left, [init_chunk]) |> Enum.reverse() |> Enum.join()
        end
    end

    defp ext_32b(val) do
        bin = :binary.encode_unsigned(val)
        <<0::size(32 - bit_size(bin))>> <> bin
    end

    defp receive_block(_socket, 0, received), do: received
    defp receive_block(socket, bytes_left, received) do
        case :gen_tcp.recv(socket, 0) do
            {:ok, chunk} ->
                n_bytes = div(bit_size(chunk), 8)
                receive_block(socket, bytes_left - n_bytes, [chunk | received])
            err -> err
        end
    end
end
