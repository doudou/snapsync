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

        # Whether this target is enabled or not
        def enabled?; @enabled end

        # Enable this target, i.e. add it to the auto synchronization and
        # cleanup commands
        def enable; @enabled = true; self end

        # Disable this target, i.e. remove it from the auto synchronization and
        # cleanup commands
        def disable; @enabled = false; self end

        # Whether the target should be autocleaned on synchronization
        #
        # Defaults to true
        def autoclean?; !!@autoclean end

        class InvalidTargetPath < RuntimeError; end
        class InvalidUUIDError < InvalidTargetPath; end
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
                @enabled = true
                @autoclean = true
            end
            write_config
        end

        def each_snapshot_raw(&block)
            Snapshot.each_snapshot_raw(dir, &block)
        end
        def each_snapshot(&block)
            Snapshot.each(dir, &block)
        end

        def write_config
            config = Hash['uuid' => uuid, 'policy' => Hash.new]
            config['policy']['type'] =
                case sync_policy
                when TimelineSyncPolicy then 'timeline'
                when SyncLastPolicy then 'last'
                when DefaultSyncPolicy then 'default'
                end
            config['policy']['options'] =
                sync_policy.to_config
            config['enabled'] = enabled?
            config['autoclean'] = autoclean?

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

            @enabled = config.fetch('enabled', true)
            @autoclean = config.fetch('autoclean', true)

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
                cleanup = TimelineSyncPolicy
            when 'last'
                sync_policy = SyncLastPolicy
                cleanup = SyncLastPolicy
            else
                raise InvalidConfiguration, "synchronization policy #{type} does not exist"
            end
            @sync_policy = sync_policy.from_config(options)
            @cleanup =
                if cleanup
                    Cleanup.new(cleanup.from_config(options))
                end
        end

        def delete(s, dry_run: false)
            Snapsync.info "Removing snapshot #{s.num} #{s.date.to_time} at #{s.subvolume_dir}"
            return if dry_run

            begin
                Btrfs.popen("subvolume", "delete", s.subvolume_dir.to_s)
            rescue Btrfs::Error
                Snapsync.warn "failed to remove snapshot at #{s.subvolume_dir}, keeping the rest of the snapshot"
                return
            end

            s.snapshot_dir.rmtree
            Snapsync.info "Flushing data to disk"
            begin
                Btrfs.popen("subvolume", "sync", s.subvolume_dir.to_s)
            rescue Btrfs::Error
            end
        end
    end
end
