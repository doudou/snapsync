module Snapsync
    class KeepLastCleanup
        def self.from_config(config)
            cleanup = new
            cleanup.parse_config(config)
            cleanup
        end

        def parse_config(config)
        end

        def cleanup(target, dry_run: false)
            snapshots = target.each_snapshot.to_a
            to_keep = snapshots.sort_by(&:num).reverse.
                find { |s| s.user_data['snapsync'] == target.uuid }

            snapshots.sort_by(&:num).each do |s|
                next if s == to_keep
                target.delete(s, dry_run: dry_run)
            end
        end
    end
end

