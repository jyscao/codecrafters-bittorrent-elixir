defmodule Bittorrent.Peer.Worker do
  use GenServer

  @block_length 16*1024   # 16 KiB
  @self_peer_id :crypto.hash(:sha, "jyscao")

  @msg_unchoke      1
  @msg_interested   2
  @msg_bitfield     5
  @msg_request      6
  @msg_piece        7
  @msg_extension    20


  def start(info_hash, peer_addr) do
    initial_state = %{
      info_hash: info_hash,
      peer_addr: peer_addr,
      socket: nil,
      readied: false,
    }
    GenServer.start(__MODULE__, initial_state)
  end

  def do_handshake(pid), do: GenServer.call(pid, :handshake)
  def inform_interest(pid), do: GenServer.call(pid, :interested)
  def download_block(pid, blk_tup), do: GenServer.call(pid, {:request, blk_tup})

  def do_magnet_handshake(pid), do: GenServer.call(pid, :magnet_handshake)
  def do_extension_handshake(pid), do: GenServer.call(pid, :extension_handshake)



  # callbacks

  @impl true
  def init(%{peer_addr: {ipv4, port}} = state) do
    opts = [:binary, active: true]
    with {:ok, socket} = :gen_tcp.connect(ipv4, port, opts) do
      {:ok, %{state | socket: socket}}
    end
  end

  @impl true
  def handle_call(:handshake, _from, %{socket: socket, info_hash: info_hash} = state) do
    handshake_msg = <<19>> <> "BitTorrent protocol" <> <<0::64>> <> info_hash <> @self_peer_id
    :ok = :gen_tcp.send(socket, handshake_msg)

    receive do
      # somtimes the bitfield message is sent together with the handshake response, which would be bound to _rest
      {:tcp, _socket, <<19>> <> "BitTorrent protocol" <> <<_ext_bytes::64, _info_hash::160, peer_id::160, _rest::binary>>}
        -> {:reply, peer_id, state}

      _ -> raise("this should never be reached")
    end
  end

  def handle_call(:interested, _from, %{socket: socket} = state) do
    with :ok = :gen_tcp.send(socket, <<1::32, @msg_interested>>),
      true = wait_for_unchoke()
    do
      {:reply, true, %{state | readied: true}}
    end
  end

  def handle_call({:request, {pce, blk, blen}}, _from, %{socket: socket, readied: true} = state) do
    blk_begin = blk * @block_length
    payload = <<@msg_request>> <> ext_32b(pce) <> ext_32b(blk_begin) <> ext_32b(blen)
    :ok = :gen_tcp.send(socket, ext_32b(bit_size(payload)) <> payload)

    block = receive do
      {:tcp, _socket, <<payload_len::32, @msg_piece, ^pce::32, ^blk_begin::32, init_chunk::binary>>} ->
        bytes_rem = payload_len - 9 - div(bit_size(init_chunk), 8)
        recv_block_chunks(bytes_rem, [init_chunk])

      _ -> raise("this should never be reached")
    end

    {:reply, block, state}
  end

  def handle_call(:magnet_handshake, _from, %{socket: socket, info_hash: info_hash} = state) do
    handshake_msg = <<19>> <> "BitTorrent protocol" <> <<0::40, 16, 0::16>> <> info_hash <> @self_peer_id
    :ok = :gen_tcp.send(socket, handshake_msg)

    receive do
      {:tcp, _socket, <<19>> <> "BitTorrent protocol" <> <<_ext_head::43, 1::1, _ext_tail::20, _info_hash::160, peer_id::160, _rest::binary>>}
        -> {:reply, {true, peer_id}, state}

      {:tcp, _socket, <<19>> <> "BitTorrent protocol" <> <<_ext_bytes::64, _info_hash::160, peer_id::160, _rest::binary>>}
        -> {:reply, {false, peer_id}, state}

      _ -> raise("this should never be reached")
    end
  end

  def handle_call(:extension_handshake, _from, %{socket: socket} = state) do
    payload = <<@msg_extension, 0>> <> "d1:md11:ut_metadatai193eee"
    :ok = :gen_tcp.send(socket, ext_32b(div(bit_size(payload), 8)) <> payload)
    {:reply, nil, state}
  end

  @impl true
  def handle_info({:tcp, _socket, <<_msg_size::32, @msg_bitfield, _bitfield::binary>>}, state), do: {:noreply, state}

  def handle_info({:tcp, _socket, _msg}, state), do: {:noreply, state}


  # helper functions

  defp recv_block_chunks(0, received), do: Enum.reverse(received) |> Enum.join()
  defp recv_block_chunks(bytes_rem, received) do
    receive do
      {:tcp, _socket, chunk} ->
        chunk_size = div(bit_size(chunk), 8)
        recv_block_chunks(bytes_rem - chunk_size, [chunk | received])

      _ -> raise("this should never be reached")
    end
  end

  defp ext_32b(val) do
    bin = :binary.encode_unsigned(val)
    <<0::size(32 - bit_size(bin))>> <> bin
  end

  defp wait_for_unchoke() do
    receive do
      {:tcp, _socket, <<1::32, @msg_unchoke>>}
        -> true

      # sometimes the bitfield message arrives during the handle_call of intetested-msg, so ignore it
      {:tcp, _socket, <<_msg_size::32, @msg_bitfield, _bitfield::binary>>}
        -> wait_for_unchoke()

      _ -> raise("this should never be reached")
    end
  end
end
