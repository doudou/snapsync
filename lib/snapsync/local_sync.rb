module Snapsync
    # Synchronization between local file systems
    class LocalSync
        # The snapper configuration we should synchronize
        # 
        # @return [SnapperConfig]
        attr_reader :config
        # The target directory into which to synchronize
        #
        # @return [LocalTarget]
        attr_reader :target
        
        def initialize(config, target)
            @config, @target = config, target
        end

        def create_synchronization_point
            config.create(
                description: "synchronization snapshot for snapsync",
                user_data: Hash['important' => 'yes', 'snapsync-description' => target.description, 'snapsync' => target.uuid])
        end

        def remove_synchronization_points(except_last: true)
            synchronization_points = config.each_snapshot.find_all do |snapshot|
                snapshot.synchronization_point_for?(target)
            end
            if except_last
                synchronization_points = synchronization_points.sort_by(&:num)
                synchronization_points.pop
            end
            synchronization_points.each do |snapshot|
                config.delete(snapshot)
            end
        end

        def copy_stream(send_io, receive_io, chunk_length: (1 << 20), estimated_size: 0)
            longest_message_length = 0
            counter = 0
            start = Time.now
            while !send_io.eof?
                if buffer = send_io.read(chunk_length) # 1MB buffer
                    receive_io.write(buffer)

                    counter += buffer.size
                    rate = counter / (Time.now - start)
                    remaining =
                        if estimated_size > counter
                            human_readable_time((estimated_size - counter) / rate)
                        elsif counter - estimated_size < 100 * 1024**2
                            human_readable_time(0)
                        else
                            '?'
                        end

                    msg = "#{human_readable_size(counter)} (#{human_readable_size(rate)}/s), #{remaining} remaining"
                    longest_message_length = [longest_message_length, msg.length].max
                    print "\r%-#{longest_message_length}s" % [msg]
                end
            end
            print "\r#{" " * longest_message_length}\r"
            counter
        end

        def synchronize_snapshot(target_snapshot_dir, src, parent: nil)
            partial_marker_path = Snapshot.partial_marker_path(target_snapshot_dir)

            # Verify first if the snapshot is already present and/or partially
            # synchronized
            begin
                snapshot = Snapshot.new(target_snapshot_dir)
                if snapshot.partial?
                    Snapsync.warn "target snapshot directory #{target_snapshot_dir} looks like an aborted snapsync synchronization, I will attempt to refresh it"
                else
                    return true
                end
            rescue InvalidSnapshot
                if target_snapshot_dir.exist?
                    Snapsync.warn "target snapshot directory #{target_snapshot_dir} already exists, but does not seem to be a valid snapper snapshot. I will attempt to refresh it"
                else
                    target_snapshot_dir.mkdir
                end
                FileUtils.touch(partial_marker_path.to_s)
            end

            if copy_snapshot(target_snapshot_dir, src, parent: parent)
                partial_marker_path.unlink
                Btrfs.popen("filesystem", "sync", target_snapshot_dir.to_s)
                Snapsync.info "Successfully synchronized #{src.snapshot_dir}"
                true
            end
        end

        def copy_snapshot(target_snapshot_dir, src, parent: nil)
            # This variable is used in the 'ensure' block. Make sure it is
            # initialized properly
            success = false

            File.open(target_snapshot_dir + "info.xml", 'w') do |io|
                io.write (src.snapshot_dir + "info.xml").read
            end

            if parent
                parent_opt = ['-p', parent.subvolume_dir.to_s]
                estimated_size = src.size_diff_from(parent)
            else
                parent_opt = []
                estimated_size = src.size
            end

            Snapsync.info "Estimating transfer for #{src.snapshot_dir} to be #{human_readable_size(estimated_size)}"

            start = Time.now
            bytes_transferred = nil
            bytes_transferred =
                Btrfs.popen('send', *parent_opt, src.subvolume_dir.to_s) do |send_io|
                    Btrfs.popen('receive', target_snapshot_dir.to_s, mode: 'w', out: '/dev/null') do |receive_io|
                        receive_io.sync = true
                        copy_stream(send_io, receive_io, estimated_size: estimated_size)
                    end
                end

            Snapsync.info "Flushing data to disk"
            Btrfs.run("filesystem", "sync", target_snapshot_dir.to_s)
            duration = Time.now - start
            rate = bytes_transferred / duration
            Snapsync.info "Transferred #{human_readable_size(bytes_transferred)} in #{human_readable_time(duration)} (#{human_readable_size(rate)}/s)"
            Snapsync.info "Successfully synchronized #{src.snapshot_dir}"
            true

        rescue Exception => e
            Snapsync.warn "Failed to synchronize #{src.snapshot_dir}, deleting target directory"
            subvolume_dir = target_snapshot_dir + "snapshot"
            if subvolume_dir.directory?
                Btrfs.run("subvolume", "delete", subvolume_dir.to_s)
            end
            if target_snapshot_dir.directory?
                target_snapshot_dir.rmtree
            end

            raise
        end

        def sync
            STDOUT.sync = true

            # First, create a snapshot and protect it against cleanup, to use as
            # synchronization point
            #
            # We remove old synchronization points on successful synchronization
            source_snapshots = config.each_snapshot.sort_by(&:num)
            sync_snapshot = source_snapshots.reverse.find do |snapshot|
                if snapshot.synchronization_point_for?(target)
                    true
                elsif !snapshot.synchronization_point?
                    break
                end
            end
            sync_snapshot ||= create_synchronization_point

            target_snapshots = target.each_snapshot.sort_by(&:num)
            nums_on_target = target_snapshots.map(&:num).to_set

            last_common_snapshot = source_snapshots.find do |s|
                nums_on_target.include?(s.num)
            end
            if !last_common_snapshot
                Snapsync.warn "no common snapshot found, will have to synchronize the first snapshot fully"
            end

            # Merge source and target snapshots to find out which are needed on
            # the target, and then remove the ones that are already present.
            all_snapshots = source_snapshots.find_all { |s| !nums_on_target.include?(s.num) } +
                target_snapshots
            nums_required = target.sync_policy.filter_snapshots(all_snapshots).
                map(&:num).to_set
            source_snapshots.each do |src|
                if !nums_required.include?(src.num)
                    if nums_on_target.include?(src.num)
                        last_common_snapshot = src
                    end
                    next
                elsif synchronize_snapshot(target.dir + src.num.to_s, src, parent: last_common_snapshot)
                    last_common_snapshot = src
                end
            end

            if synchronize_snapshot(target.dir + sync_snapshot.num.to_s, sync_snapshot, parent: last_common_snapshot)
                Snapsync.debug "successfully copied last synchronization point #{sync_snapshot.num}, removing old ones"
                remove_synchronization_points
            end

            last_common_snapshot
        end

        def human_readable_time(time)
            hrs = time / 3600
            min = (time / 60) % 60
            sec = time % 60
            "%02i:%02i:%02i" % [hrs, min, sec]
        end

        def human_readable_size(size, digits: 1)
            order = ['B', 'kB', 'MB', 'GB']
            magnitude =
                if size > 0
                    Integer(Math.log2(size) / 10)
                else 0
                end
            "%.#{digits}f#{order[magnitude]}" % [Float(size) / (1024 ** magnitude)]
        end
    end
end

