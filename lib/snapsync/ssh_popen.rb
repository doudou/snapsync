module Snapsync
    class SSHPopen
        class NonZeroExitCode < RuntimeError
        end
        class ExitSignal < RuntimeError
        end

        # @return [IO]
        attr_reader :read_buffer

        # @return [IO]
        attr_reader :write_buffer

        # @param machine [RemotePathname]
        # @param [Array] command
        # @param options [Hash]
        def initialize(machine, command, **options)
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
                    channel = ssh.open_channel do |channel|
                        Snapsync.debug "SSHPopen channel opened: #{channel}"

                        channel.on_data do |ch, data|
                            read_buffer_in.write(data)
                        end
                        channel.on_extended_data do |ch, data|
                            data = data.chomp
                            if data.length > 0
                                Snapsync.error data
                            end
                        end

                        channel.on_request("exit-status") do |ch2, data|
                            code = data.read_long
                            if code != 0
                                raise NonZeroExitCode, "Exited with code: #{code}"
                            else
                                Snapsync.debug "SSHPopen command finished."
                            end
                        end

                        channel.on_request("exit-signal") do |ch2, data|
                            exit_signal = data.read_long
                            raise ExitSignal, "Exited due to signal: #{exit_signal}"
                        end

                        channel.on_process do
                            begin
                                channel.send_data(write_buffer_out.read_nonblock(2 << 20))
                            rescue IO::EAGAINWaitReadable
                            end
                        end

                        channel.exec(Shellwords.join command)
                    end

                    ssh.loop(0.001) {
                        if write_buffer_out.closed?
                            channel.close
                        end

                        channel.active?
                    }

                    Snapsync.debug "SSHPopen session closed"
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
