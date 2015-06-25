module Snapsync
    # Synchronization between local file systems
    class LocalSync
        # The snapper configuration we should synchronize
        # 
        # @return [SnapperConfig]
        attr_reader :config
        # The target directory into which to synchronize
        #
        # @return [Pathname]
        attr_reader :target_dir

        def initialize(config, target_dir)
            if !target_dir.directory?
                raise ArgumentError, "#{target_dir} does not exist"
            end
            @config, @target_dir = config, target_dir
        end

        def sync
            source_snapshots = config.each_snapshot.sort_by(&:num)
            target_snapshots = Snapshot.each(target_dir).sort_by(&:num)

            last_common_snapshot = source_snapshots.find do |s|
                target_snapshots.find { |src| src.num == s.num }
            end
            if !last_common_snapshot
                Snapsync.warn "no common snapshot found, will have to synchronize the first snapshot fully"
            end

            source_snapshots.each do |src|
                if !target_snapshots.find { |s| s.num == src.num }
                    target_snapshot_dir = (target_dir + src.num.to_s)
                    if target_snapshot_dir.exist?
                        Snapsync.warn "target snapshot directory #{target_snapshot_dir} already exists, but does not seem to be a valid snapper snapshot, I won't synchronize the source"
                        next
                    end

                    success = false
                    target_snapshot_dir.mkdir
                    begin
                        File.open(target_snapshot_dir + "info.xml", 'w') do |io|
                            io.write (src.snapshot_dir + "info.xml").read
                        end

                        if last_common_snapshot
                            parent_opt = ['-p', last_common_snapshot.subvolume_dir.to_s]
                            estimated_size = src.size_diff_from(last_common_snapshot)
                        else
                            parent_opt = []
                            estimated_size = src.size
                        end

                        puts "Estimating transfer to be #{human_readable_size(estimated_size)}"

                        longest_message_length = 0
                        receive_status, send_status = nil
                        IO.popen(['sudo', 'btrfs', 'send', *parent_opt, src.subvolume_dir.to_s]) do |send_io|
                            IO.popen(['sudo', 'btrfs', 'receive', target_snapshot_dir.to_s], 'w') do |receive_io|
                                receive_io.sync = true
                                counter = 0
                                start = Time.now
                                while !send_io.eof?
                                    if buffer = send_io.read(20 << 20)
                                        receive_io.write(buffer)

                                        counter += buffer.size
                                        rate = counter / (Time.now - start)
                                        remaining =
                                            if estimated_size > counter
                                                human_readable_time((estimated_size - counter) / rate)
                                            else
                                                '?'
                                            end

                                        msg = "#{human_readable_size(counter)} (#{human_readable_size(rate)}/s), #{remaining} remaining"
                                        longest_message_length = [longest_message_length, msg.length].max
                                        print "\r%#{longest_message_length}s" % [msg]
                                    end
                                end
                                rate = counter / (Time.now - start)
                                puts "Transferred #{human_readable_size(counter)} in #{human_readable_size(rate)}/s"
                            end
                            receive_status = $?
                        end
                        send_status = $?
                        success = (receive_status.success? && send_status.success?)

                        if success
                            Snapsync.info "Successfully synchronized #{src.snapshot_dir}"
                            last_common_snapshot = src
                            system("sudo", "btrfs", "filesystem", "sync", target_snapshot_dir.to_s)
                        end

                    rescue EOFError
                    ensure
                        if !success
                            Snapsync.warn "Failed to synchronize #{src.snapshot_dir}, deleting target directory"
                            subvolume_dir = target_snapshot_dir + "snapshot"
                            if subvolume_dir.directory?
                                system("sudo btrfs subvolume delete #{subvolume_dir}")
                            end
                            target_snapshot_dir.rmtree
                        end
                    end
                else
                    Snapsync.info "Snapshot #{src.snapshot_dir} already present on the target"
                    last_common_snapshot = src
                end
            end
        end

        def human_readable_time(time)
            hrs = time / 3600
            min = (time / 60) % 60
            sec = time % 60
            "%02i:%02i:%02i" % [hrs, min, sec]
        end

        def human_readable_size(size, digits: 1)
            order = ['', 'k', 'M', 'G']
            magnitude = Integer(Math.log2(size) / 10)
            "%.#{digits}f#{order[magnitude]}" % [Float(size) / (1024 ** magnitude)]
        end
    end
end

