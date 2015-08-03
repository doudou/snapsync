module Snapsync
    # Synchronizes all snapshots to a directory
    #
    # A snapshot will be synchronized if (1) the target directory has a
    # subdirectory of the config's name and (2) this directory is not
    # disabled through its config file
    class SyncAll
        # The path to the directory containing snapper configuration files
        attr_reader :config_dir
        # The path to the root directory to which we should sync
        attr_reader :target_dir

        # Creates a sync-all operation for the given target directory
        #
        # @param [Pathname] target_dir the target directory
        # @param [Boolean,nil] autoclean if true or false, will control
        #   whether the targets should be cleaned of obsolete snapshots
        #   after synchronization. If nil (the default), the target's own
        #   autoclean flag will be used to determine this
        def initialize(target_dir, config_dir: Pathname.new('/etc/snapper/configs'), autoclean: nil)
            @config_dir = config_dir
            @target_dir = target_dir
            @autoclean  = autoclean
        end

        # Whether the given target should be cleaned after synchronization.
        # 
        # This is determined either by {#autoclean?} if {.new} was called with
        # true or false, or by the target's own autoclean flag if {.new} was
        # called with nil
        def should_autoclean_target?(target)
            if @autoclean.nil?
                target.autoclean?
            else
                @autoclean
            end
        end

        def run
            SnapperConfig.each_in_dir(config_dir) do |config|
                dir = target_dir + config.name
                if !dir.exist?
                    Snapsync.warn "not synchronizing #{config.name}, there are no corresponding directory in #{target_dir}. Call snapsync init to create a proper target directory"
                else
                    target = LocalTarget.new(dir)
                    if !target.enabled?
                        Snapsync.warn "not synchronizing #{config.name}, it is disabled"
                        next
                    end

                    LocalSync.new(config, target).sync
                    if should_autoclean_target?(target)
                        if target.cleanup
                            Snapsync.info "running cleanup for #{config.name}"
                            target.cleanup.cleanup(target)
                        else
                            Snapsync.info "#{target.sync_policy.class.name} policy set, no cleanup to do for #{config.name}"
                        end
                    else
                        Snapsync.info "autoclean not set on #{config.name}"
                    end
                end
            end
        end
    end
end

