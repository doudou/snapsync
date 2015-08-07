module Snapsync
    # Exception thrown when performing sanity checks on the values returned by
    # the policy. Snapsync usually aborts in these cases, given how this is
    # critical
    class InvalidPolicy < RuntimeError; end

    # Default synchronization policy
    #
    # Synchronization policy objects are used by the synchronization passes to
    # decide which snapshots to copy and which to not copy. They have to provide
    # {#filter_snapshots}.
    #
    # This default policy is to copy everything but the snapsync-created
    # synchronization points that are not involving the current target
    class DefaultSyncPolicy
        def self.from_config(config)
            new
        end

        def to_config
            Array.new
        end

        # Returns the snapshots that should be synchronized according to this
        # policy
        #
        # @param [#uuid] target the target object
        # @param [Array<Snapshot>] the snapshot candidates
        # @return [Array<Snapshot>] the snapshots that should be copied
        def filter_snapshots(snapshots)
            # Filter out any snapsync-generated snapshot
            snapshots.find_all { |s| !s.synchronization_point? }
        end

        # Pretty prints this policy
        #
        # This is used by the CLI to give information about a target to the user
        def pretty_print(pp)
            pp.text "default policy"
        end
    end
end
