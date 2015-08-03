require 'thor'
require 'snapsync'

module Snapsync
    class CLI < Thor
        class_option :debug, type: :boolean, default: false

        no_commands do
            def snapper_config_dir
                Pathname.new("/etc/snapper/configs")
            end

            def config_from_name(name)
                path = Pathname.new(name)
                if !path.exist?
                    path = snapper_config_dir + path
                    if !path.exist?
                        raise ArgumentError, "cannot find any snapper configuration called #{name}"
                    end
                end
                SnapperConfig.load(path)
            end

            def each_snapper_config
                snapper_config_dir.each_entry do |config_file|
                    config_name = config_file.to_s
                    config_file = snapper_config_dir + config_file
                    next if !config_file.file?
                    begin
                        yield(SnapperConfig.load(config_file))
                    rescue Exception => e
                        Snapsync.warn "not processing #{config_file}: #{e.message}"
                        e.backtrace.each do |line|
                            Snapsync.debug "  #{line}"
                        end
                        nil
                    end
                end
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
        option :autoclean, type: :boolean, default: true
        def sync_all(dir)
            handle_class_options

            dir = Pathname.new(dir)
            each_snapper_config do |config|
                target_dir = dir + config.name
                if !target_dir.exist?
                    Snapsync.warn "not synchronizing #{config.name}, there are no corresponding directory in #{dir}. Call snapsync policy to create a proper target directory"
                else
                    target = LocalTarget.new(target_dir)
                    if !target.enabled?
                        Snapsync.warn "not synchronizing #{config.name}, it is disabled"
                        next
                    end

                    LocalSync.new(config, target).sync
                    if options[:autoclean] 
                        if target.cleanup
                            Snapsync.info "running cleanup"
                            target.cleanup.cleanup(target)
                        else
                            Snapsync.info "#{target.sync_policy.class.name} policy set, no cleanup to do"
                        end
                    end
                end
            end
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
                dir.mkdir
            end

            target = LocalTarget.new(dir)
            target.change_policy(type, options)
            target.write_config
        end

        desc 'info DIR', 'display information about the given snapsync target'
        def info(dir)
            handle_class_options
            target = LocalTarget.new(Pathname.new(dir))
            puts "UUID: #{target.uuid}"
            pp target.sync_policy
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

        desc "auto", "automatic synchronization"
        def auto
            require 'snapsync/async'
            require 'snapsync/async/auto'
            auto = Async::Auto.new(snapper_config_dir)
            auto.load_config(Pathname.new('/etc/snapsync.conf'))
            auto.run(self)
        end
    end
end

