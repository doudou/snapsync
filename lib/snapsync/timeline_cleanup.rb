module Snapsync
    class TimelineCleanup
        # The underlying timeline policy object that we use to compute which
        # snapshots to delete and which to keep
        attr_reader :timeline_policy

        def initialize(reference: Time.at(Time.now.to_i))
            @timeline_policy = TimelineSyncPolicy.new(reference: reference)
        end

        def self.from_config(config)
            cleanup = new
            cleanup.parse_config(config)
            cleanup
        end

        def parse_config(config)
            timeline_policy.parse_config(config)
        end

        def add(period, count)
            timeline_policy.add(period, count)
        end

        def cleanup(target, dry_run: false)
            snapshots = target.each_snapshot.to_a
            filtered_snapshots = timeline_policy.filter_snapshots_to_sync(target, snapshots).to_set

            snapshots.sort_by(&:num).each do |s|
                if !filtered_snapshots.include?(s)
                    target.delete(s, dry_run: dry_run)
                end
            end
        end
    end
end

