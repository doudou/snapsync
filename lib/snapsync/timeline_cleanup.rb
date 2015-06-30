module Snapsync
    class TimelineCleanup
        attr_reader :config, :target_dir, :timeline, :reference
        def initialize(config, target_dir, reference: Time.at(Time.now.to_i))
            if !target_dir.directory?
                raise ArgumentError, "#{target_dir} does not exist"
            end
            @config, @target_dir = config, target_dir
            @timeline = Array.new
            @reference = reference
        end

        def add(period, count)
            reference_date = reference.to_date
            reference_time_since_midnight =
                reference.to_i - reference_date.to_time.to_i

            timeline = self.timeline.dup
            new_dates = Array.new
            if period == :year
                count.times do
                    new_dates << reference_date
                    reference_date = reference_date.prev_year
                end
            elsif period == :month
                count.times do
                    new_dates << reference_date
                    reference_date = reference_date.prev_month
                end
            elsif period == :week
                count.times do
                    new_dates << reference_date
                    reference_date = reference_date.prev_day(7)
                end
            elsif period == :day
                count.times do
                    new_dates << reference_date
                    reference_date = reference_date.prev_day
                end
            elsif period == :hour
                count.times do |i|
                    timeline << reference - i * 3600
                end
            else
                raise ArgumentError, "unknown period name #{period}"
            end

            new_dates.each do |date|
                timeline << date.to_time + reference_time_since_midnight
            end
            @timeline = timeline.sort.uniq
        end

        def compute_required_snapshots(target_snapshots)
            keep_flags = Hash.new { |h,k| h[k] = [false, []] }
            # First, keep all snapshots that are still present in the source
            config.each_snapshot.each { |s| keep_flags[s.num] = [true, ["present on source"]] }

            # For each timepoint in the timeline, find the newest snapshot that
            # is not before the timepoint
            merged_timelines = (target_snapshots.to_a + timeline).sort_by do |s|
                s.to_time
            end
            matching_snapshots = [target_snapshots.first]
            merged_timelines.each do |obj|
                if obj.kind_of?(Snapshot)
                    matching_snapshots[-1] = obj
                else
                    s = matching_snapshots.last
                    matching_snapshots[-1] = [s, obj]
                    matching_snapshots << s
                end
            end
            matching_snapshots.pop
            matching_snapshots.each do |(s, timepoint)|
                keep_flags[s.num][0] = true
                keep_flags[s.num][1] << "timeline(#{timepoint})"
            end

            # Finally, guard against race conditions. Always keep all snapshots
            # between the last-to-keep and the last
            target_snapshots.sort_by(&:num).reverse.each do |s|
                break if keep_flags[s.num][0]
                keep_flags[s.num] = [true, "last snapshots"]
            end
            keep_flags
        end

        def cleanup
            target_snapshots = Snapshot.each(target_dir)

            keep_flags = compute_required_snapshots(target_snapshots)
            target_snapshots.each do |s|
                keep, reason = keep_flags.fetch(s.num, nil)
                if keep
                    Snapsync.debug "Keeping snapshot #{s.num} #{s.date.to_time}"
                    reason.each do |r|
                        Snapsync.debug "  #{r}"
                    end
                else
                    Snapsync.info "Removing snapshot #{s.num} #{s.date.to_time} at #{s.subvolume_dir}"
                    IO.popen(["sudo", "btrfs", "subvolume", "delete", s.subvolume_dir.to_s, err: '/dev/null']) do |io|
                        io.read
                    end
                    if $?.success?
                        s.snapshot_dir.rmtree
                        Snapsync.info "Flushing data to disk"
                        IO.popen(["sudo", "btrfs", "filesystem", "sync", s.snapshot_dir.to_s, err: '/dev/null']).read
                    else
                        Snapsync.warn "failed to remove snapshot at #{s.subvolume_dir}, keeping the rest of the snapshot"
                    end

                end
            end
        end
    end
end

