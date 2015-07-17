module Snapsync
    class LocalTarget
        # The target's UUID
        #
        # @return [String]
        attr_reader :uuid

        # This target's directory
        attr_reader :dir

        # The target sync policy
        attr_reader :sync_policy

        # The cleanup object
        attr_reader :cleanup

        class InvalidUUIDError < RuntimeError; end
        class NoUUIDError < InvalidUUIDError; end

        def initialize(dir, create_if_needed: true)
            if !dir.directory?
                raise ArgumentError, "#{dir} does not exist"
            end
            @dir = dir

            begin
                read_config
            rescue NoUUIDError
                if !create_if_needed
                    raise
                end
                @uuid = SecureRandom.uuid
                @sync_policy = DefaultSyncPolicy.new
                @cleanup = nil
            end
            write_config
        end

        def each_snapshot(&block)
            Snapshot.each(dir, &block)
        end

        def write_config
            config = Hash['uuid' => uuid, 'policy' => Hash.new]
            config['policy']['type'] =
                case sync_policy
                when TimelineSyncPolicy then 'timeline'
                when DefaultSyncPolicy then 'default'
                end
            config['policy']['options'] =
                sync_policy.to_config

            File.open(config_path, 'w') do |io|
                io.write YAML.dump(config)
            end
        end

        def read_config
            begin
                raw_config = YAML.load(config_path.read)
            rescue Errno::ENOENT => e
                raise NoUUIDError, e.message, e.backtrace
            end
            parse_config(raw_config)
        end

        def parse_config(config)
            uuid = config['uuid']
            if uuid.length != 36
                raise InvalidUUIDError, "uuid in #{uuid_path} was expected to be 36 characters long, but is #{uuid.length}"
            end
            @uuid = uuid

            if policy_config = config['policy']
                change_policy(policy_config['type'], policy_config['options'] || Array.new)
            else
                @sync_policy = DefaultSyncPolicy.new
                @cleanup = nil
            end
        end

        # Path to the target's configuration file
        #
        # @return [Pathname]
        def config_path
            dir + "snapsync.config"
        end
        
        def change_policy(type, options)
            case type
            when 'default'
                sync_policy = DefaultSyncPolicy
                cleanup = nil
            when 'timeline'
                sync_policy = TimelineSyncPolicy
                cleanup = TimelineCleanup
            else
                raise InvalidConfiguration, "synchronization policy #{type} does not exist"
            end
            @sync_policy = sync_policy.from_config(options)
            @cleanup =
                if cleanup
                    cleanup.from_config(options)
                end
        end

        def delete(s, dry_run: false)
            Snapsync.info "Removing snapshot #{s.num} #{s.date.to_time} at #{s.subvolume_dir}"
            return if dry_run

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
