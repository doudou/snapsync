module Snapsync
    # Implementation of the auto-sync feature
    #
    # This class implements the 'snapsync auto' functionality. It monitors for
    # partition availability, and will run sync-all on each (declared) targets
    # when they are available, optionally auto-mounting them
    class AutoSync
        AutoSyncTarget = Struct.new :partition_uuid, :path, :automount, :name

        attr_reader :config_dir
        attr_reader :targets
        attr_reader :partitions

        DEFAULT_CONFIG_PATH = Pathname.new('/etc/snapsync.conf')

        def self.load_default
            result = new
            result.load_config
            result
        end

        def initialize(config_dir = SnapperConfig.default_config_dir)
            @config_dir = config_dir
            @targets = Hash.new
            @partitions = PartitionsMonitor.new
        end

        def load_config(path = DEFAULT_CONFIG_PATH)
            conf = YAML.load(path.read) || Array.new
            parse_config(conf)
        end

        def parse_config(conf)
            conf.each do |hash|
                target = AutoSyncTarget.new
                hash.each { |k, v| target[k] = v }
                target.path = Pathname.new(target.path)
                add(target)
            end
        end

        def write_config(path)
            data = each_autosync_target.map do |target|
                Hash['partition_uuid' => target.partition_uuid,
                     'path' => target.path.to_s,
                     'automount' => !!target.automount,
                     'name' => target.name]
            end
            File.open(path, 'w') do |io|
                YAML.dump(data, io)
            end
        end

        # Enumerates the declared autosync targets
        #
        # @yieldparam [AutoSync] target
        # @return [void]
        def each_autosync_target
            return enum_for(__method__) if !block_given?
            targets.each_value do |targets|
                targets.each { |t| yield(t) }
            end
        end

        # Enumerates the available autosync targets
        #
        # It may mount partitions as needed
        #
        # @yieldparam [Pathname] path the path to the target's base dir
        #   (suitable to be processed by e.g. AutoSync)
        # @yieldparam [AutoSyncTarget] target the target located at 'path'
        # @return [void]
        def each_available_autosync_target
            return enum_for(__method__) if !block_given?
            partitions.poll

            partitions.known_partitions.each do |uuid, fs|
                autosync_targets = targets[uuid]
                next if autosync_targets.empty?

                mp = fs['MountPoints'].first
                if mp
                    mp = Pathname.new(mp[0..-2].pack("U*"))
                end

                begin
                    mounted = false

                    if !mp
                        if !autosync_targets.any?(&:automount)
                            Snapsync.info "partition #{uuid} is present, but not mounted and automount is false. Ignoring"
                            next
                        end

                        Snapsync.info "partition #{uuid} is present, but not mounted, automounting"
                        begin
                            mp = fs.Mount([]).first
                        rescue Exception => e
                            Snapsync.warn "failed to mount, ignoring this target"
                            next
                        end
                        mp = Pathname.new(mp)
                        mounted = true
                    end

                    autosync_targets.each do |target|
                        yield(mp + target.path, target)
                    end

                ensure
                    if mounted
                        fs.Unmount([])
                    end
                end
            end
        end

        # Enumerates the available synchronization targets
        #
        # It may mount partitions as needed
        #
        # @yieldparam [LocalTarget] target the available target
        # @return [void]
        def each_available_target
            return enum_for(__method__) if !block_given?
            each_available_autosync_target do |path, t|
                op = SyncAll.new(path, config_dir: config_dir)
                op.each_target do |target|
                    yield(target)
                end
            end
        end

        def add(target)
            targets[target.partition_uuid] ||= Array.new
            targets[target.partition_uuid] << target
            partitions.monitor_for(target.partition_uuid)
        end

        def remove(**matcher)
            targets.delete_if do |uuid, list|
                list.delete_if do |t|
                    matcher.all? { |k, v| t[k] == v }
                end
                list.empty?
            end
        end

        def run(period: 60)
            while true
                each_available_autosync_target do |path, t|
                    Snapsync.info "sync-all on #{path} (partition #{t.partition_uuid})"
                    op = SyncAll.new(path, config_dir: config_dir)
                    op.run
                end
                Snapsync.info "done all declared autosync partitions, sleeping #{period}s"
                sleep period
            end
        end
    end
end

