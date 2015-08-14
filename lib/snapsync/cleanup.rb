module Snapsync
    class Cleanup
        # The underlying timeline policy object that we use to compute which
        # snapshots to delete and which to keep
        attr_reader :policy

        def initialize(policy)
            @policy = policy
        end

        def cleanup(target, dry_run: false)
            snapshots = target.each_snapshot.to_a
            filtered_snapshots = policy.filter_snapshots(snapshots).to_set

            if filtered_snapshots.any? { |s| s.synchronization_point? }
                raise InvalidPolicy, "#{policy} returned a snapsync synchronization point in its results"
            end

            if filtered_snapshots.empty?
                raise InvalidPolicy, "#{policy} returned no snapshots"
            end

            last_sync_point = snapshots.
                sort_by(&:num).reverse.
                find { |s| s.synchronization_point_for?(target) }
            filtered_snapshots << last_sync_point
            filtered_snapshots = filtered_snapshots.to_set

            deleted_snapshots = snapshots.sort_by(&:num).find_all do |s|
                if !filtered_snapshots.include?(s)
                    target.delete(s, dry_run: dry_run)
                    true
                end
            end

            if !deleted_snapshots.empty?
                Snapsync.info "Waiting for subvolumes to be deleted"
                deleted_snapshots.each do |s|
                    begin
                        Btrfs.popen("subvolume", "sync", s.subvolume_dir.to_s)
                    rescue Btrfs::Error
                    end
                end
            end
        end
    end
end

