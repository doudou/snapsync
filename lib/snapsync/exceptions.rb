module Snapsync
    # Exception raised when a snapshot directory is given to {Snapshot} that
    # does not look like a snapshot at all
    class InvalidSnapshot < RuntimeError; end
    # Exception raised when a snapshot directory is given to {Snapshot} but
    # snapshot_dir/info.xml does not look like a valid snapper info file.
    class InvalidInfoFile < InvalidSnapshot; end
    # Invalid configuration requested
    class InvalidConfiguration < ArgumentError; end
end
