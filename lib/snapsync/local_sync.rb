module Snapsync
    # Synchronization between local file systems
    class LocalSync
        # The snapper configuration we should synchronize
        # 
        # @return [SnapperConfig]
        attr_reader :config
        # The target directory into which to synchronize
        #
        # @return [Pathname]
        attr_reader :target_dir

        def initialize(config, target_dir)
            @config, @target_dir = config, target_dir
        end
    end
end

