module Snapsync
    class SSHPopen
        # @return [IO]
        attr_reader :read_buffer

        # @return [IO]
        attr_reader :write_buffer

        # @param machine [RemotePathname]
        # @param [Array] command
        # @param options [Hash]
        def initialize(machine, command, options)
            @read_buffer, read_buffer_in = IO.pipe
            write_buffer_out, @write_buffer = IO.pipe

            if options[:out]
                read_buffer_in = File.open(options[:out], "w")
            end

            ready = Concurrent::AtomicBoolean.new(false)
            @ssh_thr = Thread.new do
                machine.dup_ssh do |ssh|
                    ready.make_true
                    if Snapsync.SSH_DEBUG
                        log = Logger.new(STDOUT)
                        log.level = Logger::DEBUG
                        ssh.logger = log
                        ssh.logger.sev_threshold = Logger::Severity::DEBUG
                    end
                    # @type [Net::SSH::Connection::Channel]
                    channel = ssh.exec(Shellwords.join command)
                    channel.on_data do
                        read_buffer_in.write(data)
                    end
                    channel.on_extended_data do
                        data = data.chomp
                        if data.length > 0
                            Snapsync.error data.chomp
                        end
                    end

                    channel.on_process do
                        begin
                            channel.send_data(write_buffer_out.read_nonblock(2 << 20))
                        rescue IO::EAGAINWaitReadable
                        end
                    end

                    ssh.loop(0.001) {
                        if write_buffer_out.closed?
                            channel.close
                        end

                        channel.active?
                    }
                    Snapsync.debug "SSHPopen channel closed"
                    read_buffer_in.close
                    write_buffer_out.close
                end
            end
            while ready.false?
                sleep 0.001
            end
        end

        def sync=(sync)
            # ignore
        end

        def read(nbytes = nil)
            read_buffer.read nbytes
        end

        def write(data)
            write_buffer.write data
        end

        def close
            write_buffer.close
        end
    end
end
