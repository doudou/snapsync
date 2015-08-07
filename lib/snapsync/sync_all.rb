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

        # Whether the target should be forced to autoclean(true), force to not
        # run cleanup (false) or use their own config file to decide (nil)
        #
        # The default is nil
        #
        # @return [Boolean,nil]
        def autoclean?
            @autoclean
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
                    Sync.new(config, target, autoclean: autoclean?).run
                end
            end
        end
    end
end

