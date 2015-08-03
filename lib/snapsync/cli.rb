require 'thor'
require 'snapsync'

module Snapsync
    class CLI < Thor
        class_option :debug, type: :boolean, default: false

        no_commands do
            def config_from_name(name)
                path = Pathname.new(name)
                if !path.exist?
                    path = SnapperConfig.default_config_dir + path
                    if !path.exist?
                        raise ArgumentError, "cannot find any snapper configuration called #{name}"
                    end
                end
                SnapperConfig.load(path)
            end

            def handle_class_options
                if options[:debug]
                    Snapsync.logger.level = 'DEBUG'
                end
            end
        end

        desc 'sync CONFIG DIR', 'synchronizes the snapper configuration CONFIG with the snapsync target DIR'
        def sync(config_name, dir)
            handle_class_options

            config = config_from_name(config_name)
            target = LocalTarget.new(Pathname.new(dir))
            LocalSync.new(config, target).sync
        end

        desc 'sync-all DIR', 'synchronizes all snapper configurations into corresponding subdirectories of DIR'
        option :autoclean, type: :boolean, default: nil,
            desc: 'whether the target should be cleaned of obsolete snapshots',
            long_desc: "The default is to use the value specified in the target's configuration file. This command line option allows to override the default"
        def sync_all(dir)
            handle_class_options

            op = SyncAll.new(dir, config_dir: SnapperConfig.default_config_dir, autoclean: options[:autoclean])
            op.run
        end

        desc 'cleanup CONFIG DIR', 'cleans up the snapsync target DIR based on the policy set by the policy command'
        option :dry_run, type: :boolean, default: false
        def cleanup(dir)
            handle_class_options

            target = LocalTarget.new(Pathname.new(dir))
            if target.cleanup
                target.cleanup.cleanup(target, dry_run: options[:dry_run])
            else
                Snapsync.info "#{target.sync_policy.class.name} policy set, nothing to do"
            end
        end

        desc 'init DIR', 'creates a synchronization target with a default policy'
        def init(dir)
            dir = Pathname.new(dir)
            if !dir.exist?
                dir.mkpath
            end

            target = LocalTarget.new(dir)
            target.change_policy('default', Hash.new)
            target.write_config
        end

        desc 'policy DIR TYPE [OPTIONS]', 'sets the synchronization and cleanup policy for the given target'
        long_desc <<-EOD
This command sets the policy used to decide which snapshots to synchronize to
the target, and which to not synchronize.

Three policy types can be used: default, last and timeline

The default policy takes no argument. It will synchronize all snapshots present in the source, and do no cleanup

The last policy takes no argument. It will synchronize (and keep) only the last snapshot

The timeline policy takes periods of time as argument (as e.g. day 10 or month 20). It will keep at least
one snapshot for each period, and for the duration specified (day 10 tells to keep one snapshot per day
for 10 days). snapsync understands the following period names: year month day hour.
        EOD
        def policy(dir, type, *options)
            handle_class_options

            dir = Pathname.new(dir)
            if !dir.exist?
                dir.mkpath
            end

            target = LocalTarget.new(dir)
            target.change_policy(type, options)
            target.write_config
        end

        desc 'destroy DIR', 'destroys a snapsync target'
        long_desc <<-EOD
While it can easily be done manually, this command makes sure that the snapshots are properly deleted
        EOD
        def destroy(dir)
            handle_class_options
            target_dir = Pathname.new(dir)
            target = LocalTarget.new(target_dir, create_if_needed: false)
            snapshots = target.each_snapshot.to_a
            snapshots.sort_by(&:num).each do |s|
                target.delete(s)
            end
            target_dir.rmtree
        end

        desc "auto-sync", "automatic synchronization"
        option :config_file, desc: "path to the config file (defaults to /etc/snapsync.conf)",
            default: '/etc/snapsync.conf'
        def auto_sync
            auto = AutoSync.new(SnapperConfig.default_config_dir)
            auto.load_config(Pathname.new(options[:config_file]))
            auto.run
        end
    end
end

