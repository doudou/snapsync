module Snapsync
    # Implementation of the auto-sync feature
    #
    # This class implements the 'snapsync auto' functionality. It monitors for
    # partition availability, and will run sync-all on each (declared) targets
    # when they are available, optionally auto-mounting them
    class AutoSync
        AutoSyncTarget = Struct.new :partition_uuid, :path, :automount

        attr_reader :config_dir
        attr_reader :targets
        attr_reader :partitions

        def initialize(config_dir = SnapperConfig.default_config_dir)
            @config_dir = config_dir
            @targets = Hash.new
            @partitions = PartitionsMonitor.new
        end

        def load_config(path)
            conf = YAML.load(path.read) || Array.new
            parse_config(conf)
        end

        def parse_config(conf)
            conf.each do |hash|
                target = AutoSyncTarget.new
                hash.each { |k, v| target[k] = v }
                add(target)
            end
        end

        def add(target)
            targets[target.partition_uuid] ||= Array.new
            targets[target.partition_uuid] << target
            partitions.monitor_for(target.partition_uuid)
        end

        def run(period: 60)
            while true
                partitions.poll
                partitions.known_partitions.each do |uuid, fs|
                    mp = fs['MountPoints'].first
                    targets[uuid].each do |t|
                        if !mp
                            if t.automount
                                Snapsync.info "partition #{t.partition_uuid} is present, but not mounted, automounting"
                                mp = fs.Mount([]).first
                                mp = Pathname.new(mp)
                                mounted = true
                            else
                                Snapsync.info "partition #{t.partition_uuid} is present, but not mounted and automount is false. Ignoring"
                                next
                            end
                        else
                            mp = Pathname.new(mp[0..-2].pack("U*"))
                        end

                        full_path = mp + t.path
                        Snapsync.info "sync-all on #{mp + t.path} (partition #{t.partition_uuid})"
                        op = SyncAll.new(mp + t.path, config_dir: config_dir)
                        op.run
                        if mounted
                            fs.Unmount([])
                        end
                    end
                end
                Snapsync.info "done all declared autosync partitions, sleeping #{period}s"
                sleep period
            end
        end
    end
end

