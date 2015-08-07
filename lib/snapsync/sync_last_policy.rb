module Snapsync
    # A simple policy that synchronizes only the last snapshot (that is,
    # snapsync's own synchronization point)
    class SyncLastPolicy
        def self.from_config(config)
            new
        end

        def to_config
            Array.new
        end

        def pretty_print(pp)
            pp.text "will keep only the latest snapshot"
        end

        # (see DefaultSyncPolicy#filter_snapshots)
        def filter_snapshots(snapshots)
            last = snapshots.sort_by(&:num).reverse.
                find { |s| !s.synchronization_point? }
            [last]
        end
    end
end
