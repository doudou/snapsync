module Snapsync
    # Default synchronization policy
    #
    # Synchronization policy objects are used by the synchronization passes to
    # decide which snapshots to copy and which to not copy. They have to provide
    # {#filter_snapshots_to_sync}.
    #
    # This default policy is to copy everything but the snapsync-created
    # synchronization points that are not involving the current target
    class DefaultSyncPolicy
        # Returns the snapshots that should be synchronized according to this
        # policy
        #
        # @param [SnapperConfig] config the snapper configuration
        # @param [#uuid] target the target object
        # @param [Array<Snapshot>] the snapshot candidates
        # @return [Array<Snapshot>] the snapshots that should be copied
        def filter_snapshots_to_sync(config, target, snapshots)
            snapshots.find_all do |s|
                snapshot_uuid = s.user_data['snapsync']
                !snapshot_uuid || snapshot_uuid == target.uuid
            end
        end
    end
end
