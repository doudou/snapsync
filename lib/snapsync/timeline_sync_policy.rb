module Snapsync
    class TimelineSyncPolicy < DefaultSyncPolicy
        attr_reader :reference
        attr_reader :timeline

        attr_reader :periods

        def initialize(reference: Time.now)
            @reference = reference
            @timeline = Array.new
            @periods = Array.new
        end

        def self.from_config(config)
            policy = new
            policy.parse_config(config)
            policy
        end

        def parse_config(config)
            config.each_slice(2) do |period, count|
                add(period.to_sym, Integer(count))
            end
        end

        def to_config
            periods.flatten
        end

        def pretty_print(pp)
            pp.text "timeline policy"
            pp.nest(2) do
                pp.seplist(periods) do |pair|
                    pp.breakable
                    pp.text "#{pair[0]}: #{pair[1]}"
                end
            end
        end

        # Add an element to the timeline
        #
        # @param [Symbol] period the period (:year, :month, :week, :day, :hour)
        # @param [Integer] count how many units of this period should be kept
        # 
        # @example keep one snapshot every day for the last 10 days
        #   cleanup.add(:day, 10)
        #
        def add(period, count)
            beginning_of_day   = reference.to_date
            beginning_of_week  = beginning_of_day.prev_day(beginning_of_day.wday + 1)
            beginning_of_month = beginning_of_day.prev_day(beginning_of_day.mday - 1)
            beginning_of_year  = beginning_of_day.prev_day(beginning_of_day.yday - 1)
            beginning_of_hour  = beginning_of_day.to_time + (reference.hour * 3600)

            timeline = self.timeline.dup
            if period == :year
                count.times do
                    timeline << beginning_of_year.to_time
                    beginning_of_year = beginning_of_year.prev_year
                end
            elsif period == :month
                count.times do
                    timeline << begining_of_month.to_time
                    begining_of_month = begining_of_month.prev_month
                end
            elsif period == :week
                count.times do
                    timeline << beginning_of_week.to_time
                    beginning_of_week = beginning_of_week.prev_day(7)
                end
            elsif period == :day
                count.times do
                    timeline << beginning_of_day.to_time
                    beginning_of_day = beginning_of_day.prev_day
                end
            elsif period == :hour
                count.times do |i|
                    timeline << beginning_of_hour
                    beginning_of_hour = beginning_of_hour - 3600
                end
            else
                raise ArgumentError, "unknown period name #{period}"
            end

            periods << [period, count]
            @timeline = timeline.sort.uniq
        end

        # Given a list of snapshots, computes those that should be kept to honor
        # the timeline constraints
        def compute_required_snapshots(target_snapshots)
            keep_flags = Hash.new { |h,k| h[k] = [false, []] }

            # Mark all important snapshots as kept
            target_snapshots.each do |s|
                if s.user_data['important'] == 'yes'
                    keep_flags[s.num][0] = true
                    keep_flags[s.num][1] << "marked as important"
                end
            end

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
                keep_flags[s.num][0] = true
                keep_flags[s.num][1] << "last snapshot"
            end
            keep_flags
        end

        def filter_snapshots_to_sync(target, source_snapshots)
            Snapsync.debug do
                Snapsync.debug "Filtering snapshots according to timeline"
                timeline.each do |t|
                    Snapsync.debug "  #{t}"
                end
                break
            end

            default_policy = DefaultSyncPolicy.new
            source_snapshots  = default_policy.filter_snapshots_to_sync(target, source_snapshots)

            keep_flags = compute_required_snapshots(source_snapshots)
            source_snapshots.sort_by(&:num).find_all do |s|
                keep, reason = keep_flags.fetch(s.num, nil)
                if keep
                    Snapsync.debug "Timeline: selected snapshot #{s.num} #{s.date.to_time}"
                    reason.each do |r|
                        Snapsync.debug "  #{r}"
                    end
                else
                    Snapsync.debug "Timeline: not selected snapshot #{s.num} #{s.date.to_time}"
                end

                keep
            end
        end
    end
end


