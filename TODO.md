# Correctness & Bugfixes

* fix ephemeral bug where peer's extension ID is nil when requesting metadata, even though it has
  been obtained earlier in the extension handshake; only encountered when running `codecrafters test`;
  see FIXME in peer_worker.ex

* also encounters the following bug on `codecrafters test/submit` occasionally:
```
remote: [tester::#QV6] Running tests for Stage #QV6 (Magnet Links - Download a piece)
remote: [tester::#QV6] Running ./your_bittorrent.sh magnet_download_piece -o /tmp/torrents3219480274/piece-0 "magnet:?xt=urn:btih:3f994a835e090238873498636b98a3e78d1c34ca&dn=magnet2.gif&tr=http%3A%2F%2Fbittorrent-test-tracker.codecrafters.io%2Fannounce" 0
remote: [your_program] ** (exit) exited in: GenServer.call(#PID<0.161.0>, :extension_handshake, 5000)
remote: [your_program]     ** (EXIT) time out
remote: [your_program]     (elixir 1.16.2) lib/gen_server.ex:1114: GenServer.call/3
remote: [your_program]     (bittorrent 1.0.0) lib/magnet_link.ex:82: MagnetLink.ready_workers/2
remote: [your_program]     (elixir 1.16.2) lib/enum.ex:1700: Enum."-map/2-lists^map/1-1-"/2
remote: [your_program]     (bittorrent 1.0.0) lib/magnet_link.ex:58: MagnetLink.download_piece/3
remote: [your_program]     (elixir 1.16.2) lib/kernel/cli.ex:136: anonymous fn/3 in Kernel.CLI.exec_fun/2
remote: [tester::#QV6] Application didn't terminate successfully without errors. Expected 0 as exit code, got: 1
remote: [tester::#QV6] Test failed (try setting 'debug: true' in your codecrafters.yml to see more details)
```

* hash the bencoded info_dict and verify info-hash matches that from the magnet link URL
* check hashes of downloaded pieces against given piece-hash, put back onto work queue if no match (also see Refactor)
* add bitfield support for each peer
* add tests



# Refactors

* create & use work queue of pieces/blocks to be downloaded, then verify hash of piece
* make all functions take metadata dict instead of the torrent file, so metadata dicts retrieved from magnet links can also be used
* clean-up & simplify PieceArithmetic implementation
* refactor to make the magnet link functions more modular
* clean-up, simplify & conslidate handling of peer's bitfield messages extension handshakes - keep in mind that they are sent in that order



# Code Organization

* create utils module to handle common data transformations (binary <-> hex, size paddings, etc.)
* use Shorthand where appropriate
