module Snapsync
    class SSHPopen
        # @return [IO]
        attr_reader :read_buffer

        # @return [Queue]
        attr_reader :write_buffer

        # @param machine [RemotePathname]
        # @param [Array] command
        def initialize(machine, command)
            @read_buffer, read_buffer_in = IO.pipe
            write_buffer_out, @write_buffer = IO.pipe

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
                    channel = ssh.exec(Shellwords.join command) do |ch, stream, data|
                        if stream == :stdout
                            read_buffer_in.write(data)
                        else
                            data = data.chomp
                            if data.length > 0
                                Snapsync.error data.chomp
                            end
                        end
                    end
                    ssh.loop {
                        begin
                            channel.send_data(write_buffer_out.read_nonblock(16 * 1024))
                        rescue IO::EAGAINWaitReadable
                        end

                        if write_buffer_out.closed?
                            channel.close
                        end

                        channel.active?
                    }
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
