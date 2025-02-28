# Correctness & Bugfixes

* fix ephemeral bug where peer's extension ID is nil when requesting metadata, even though it has
  been obtained earlier in the extension handshake; only encountered when running `codecrafters test`;
  see FIXME in peer_worker.ex
* hash the bencoded info_dict and verify info-hash matches that from the magnet link URL



# Refactors

* make all functions take metadata dict instead of the torrent file, so metadata dicts retrieved from magnet links can also be used
* use Shorthand where appropriate
* clean-up & simplify PieceArithmetic implementation
* refactor to make the magnet link functions more modular
* clean-up, simplify & conslidate handling of peer's bitfield messages extension handshakes - keep in mind that they are sent in that order
