module Snapsync
    # Single-target synchronization
    class Sync
        attr_reader :config

        # @return [SyncTarget]
        attr_reader :target

        def initialize(config, target, autoclean: nil)
            @config = config
            @target = target
            @autoclean =
                if autoclean.nil? then target.autoclean?
                else autoclean
                end
        end

        # Whether the target should be cleaned after synchronization.
        # 
        # This is determined either by {#autoclean?} if {.new} was called with
        # true or false, or by the target's own autoclean flag if {.new} was
        # called with nil
        def autoclean?
            @autoclean
        end

        # The method that performs synchronization
        #
        # One usually wants to call {#run}, which also takes care of running
        # cleanup if {#autoclean?} is true
        def sync
            SnapshotTransfer.new(config, target).sync
        end

        def remove_partially_synchronized_snapshots
            btrfs_target = Btrfs.get(@target.dir)

            target.each_snapshot_raw do |path, snapshot, error|
                next if !error && !snapshot.partial?

                Snapsync.info "Removing partial snapshot at #{path}"
                begin
                    if (path + "snapshot").exist?
                        btrfs_target.run("subvolume", "delete", (path + "snapshot").path_part)
                    elsif (path + "snapshot.partial").exist?
                        btrfs_target.run("subvolume", "delete", (path + "snapshot.partial").path_part)
                    end
                rescue Btrfs::Error => e
                    Snapsync.warn "failed to remove snapshot at #{path}, keeping the rest of the snapshot"
                    Snapsync.warn e.message
                    next
                end

                path.rmtree
                Snapsync.info "Flushing data to disk"
                begin
                    btrfs_target.run("subvolume", "sync", path.path_part)
                rescue Btrfs::Error
                    # Ignored
                end
            end
        end

        def run
            if autoclean?
                remove_partially_synchronized_snapshots
            end

            sync

            if autoclean?
                if target.cleanup
                    Snapsync.info "running cleanup for #{target.dir}"
                    target.cleanup.cleanup(target)
                else
                    Snapsync.info "#{target.sync_policy.class.name} policy set, no cleanup to do for #{target.dir}"
                end
            else
                Snapsync.info "autoclean not set on #{target.dir}"
            end
        end
    end
end

