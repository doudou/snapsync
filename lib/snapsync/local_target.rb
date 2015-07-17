module Snapsync
    class LocalTarget
        # The target's UUID
        #
        # @return [String]
        attr_reader :uuid

        # This target's directory
        attr_reader :dir

        class InvalidUUIDError < RuntimeError; end
        class NoUUIDError < InvalidUUIDError; end

        def initialize(dir)
            if !dir.directory?
                raise ArgumentError, "#{dir} does not exist"
            end
            @dir = dir

            begin
                read_config
            rescue NoUUIDError
                @uuid = SecureRandom.uuid
                write_config
            end
        end

        def each_snapshot(&block)
            Snapshot.each(dir, &block)
        end

        def write_config
            File.open(config_path, 'w') do |io|
                io.write YAML.dump(Hash['uuid' => uuid])
            end
        end

        def read_config
            begin
                raw_config = YAML.load(config_path.read)
            rescue Errno::ENOENT => e
                raise NoUUIDError, e.message, e.backtrace
            end

            uuid = raw_config['uuid']
            if uuid.length != 36
                raise InvalidUUIDError, "uuid in #{uuid_path} was expected to be 36 characters long, but is #{uuid.length}"
            end
            @uuid = uuid
        end

        # Path to the target's UUID file
        def config_path
            dir + "snapsync.config"
        end
    end
end
