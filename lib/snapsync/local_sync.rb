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
        # The synchronization policy
        #
        # This is the object that decides which snapshots to copy and which to
        # not copy
        #
        # @see DefaultSyncPolicy
        attr_reader :policy
        
        def initialize(config, target, policy: DefaultSyncPolicy.new)
            @config, @target = config, target
            @policy = policy
        end

        def create_synchronization_point
            config.create(
                description: "synchronization snapshot for snapsync",
                user_data: Hash['important' => 'yes', 'snapsync' => target.uuid])
        end

        def remove_synchronization_points(except: nil)
            except_num = if except then except.num end

            to_delete = config.each_snapshot.find_all do |snapshot|
                (snapshot.num != except_num) &&
                    (snapshot.user_data['snapsync'] == target.uuid)
            end
            to_delete.each do |snapshot|
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
            receive_status, send_status = nil
            err_send_pipe_r, err_send_pipe_w = IO.pipe
            err_receive_pipe_r, err_receive_pipe_w = IO.pipe
            IO.popen(['sudo', 'btrfs', 'send', *parent_opt, src.subvolume_dir.to_s, err: err_send_pipe_w]) do |send_io|
                err_send_pipe_w.close
                IO.popen(['sudo', 'btrfs', 'receive', target_snapshot_dir.to_s, err: err_receive_pipe_w, out: '/dev/null'], 'w') do |receive_io|
                    err_receive_pipe_w.close
                    receive_io.sync = true
                    bytes_transferred = copy_stream(send_io, receive_io, estimated_size: estimated_size)
                end
                receive_status = $?
            end
            send_status = $?

            success = (receive_status.success? && send_status.success?)
            if !send_status.success?
                Snapsync.warn "btrfs send reported an error"
                err_send_pipe_w.readlines.each do |line|
                    Snapsync.warn "  #{line.chomp}"
                end
            end

            if !receive_status.success?
                Snapsync.warn "btrfs receive reported an error"
                err_receive_pipe_w.readlines.each do |line|
                    Snapsync.warn "  #{line.chomp}"
                end
            end

            if success
                Snapsync.info "Flushing data to disk"
                IO.popen(["sudo", "btrfs", "filesystem", "sync", target_snapshot_dir.to_s, err: '/dev/null']).read
                duration = Time.now - start
                rate = bytes_transferred / duration
                Snapsync.info "Transferred #{human_readable_size(bytes_transferred)} in #{human_readable_time(duration)} (#{human_readable_size(rate)}/s)"
                Snapsync.info "Successfully synchronized #{src.snapshot_dir}"
                true
            end

        ensure
            if !success
                Snapsync.warn "Failed to synchronize #{src.snapshot_dir}, deleting target directory"
                subvolume_dir = target_snapshot_dir + "snapshot"
                if subvolume_dir.directory?
                    IO.popen(["sudo", "btrfs", "subvolume", "delete", subvolume_dir.to_s, err: '/dev/null']).read
                end
                target_snapshot_dir.rmtree
            end
        end

        def sync
            STDOUT.sync = true

            # First, create a snapshot and protect it against cleanup, to use as
            # synchronization point
            #
            # We remove old synchronization points on successful synchronization
            sync_snapshot_id = create_synchronization_point

            source_snapshots = config.each_snapshot.sort_by(&:num)
            target_snapshots = target.each_snapshot.sort_by(&:num)

            last_common_snapshot = source_snapshots.find do |s|
                target_snapshots.find { |src| src.num == s.num }
            end
            if !last_common_snapshot
                Snapsync.warn "no common snapshot found, will have to synchronize the first snapshot fully"
            end

            snapshots_to_sync = policy.filter_snapshots_to_sync(self, target, source_snapshots)
            snapshots_to_sync.each do |src|
                if target_snapshots.find { |s| s.num == src.num }
                    Snapsync.debug "Snapshot #{src.snapshot_dir} already present on the target"
                    last_common_snapshot = src
                    next
                end

                target_snapshot_dir = (target.dir + src.num.to_s)
                partial_marker_path = target_snapshot_dir + "snapsync-partial"
                if target_snapshot_dir.exist?
                    if partial_marker_path.exist?
                        Snapsync.warn "target snapshot directory #{target_snapshot_dir} looks like an aborted snapsync synchronization, I will attempt to refresh it"
                    else
                        Snapsync.warn "target snapshot directory #{target_snapshot_dir} already exists, but does not seem to be a valid snapper snapshot. I will attempt to refresh it"
                    end
                else
                    target_snapshot_dir.mkdir
                    FileUtils.touch(partial_marker_path.to_s)
                end

                if copy_snapshot(target_snapshot_dir, src, parent: last_common_snapshot)
                    partial_marker_path.unlink
                    last_common_snapshot = src
                end
            end

            remove_synchronization_points(except: sync_snapshot_id)
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

