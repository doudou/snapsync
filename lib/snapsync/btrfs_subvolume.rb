module Snapsync
  # Output of `btrfs subvolume list`
  class SubvolumeMinimalInfo
    attr_reader :id
    attr_reader :uuid
    attr_reader :path

    attr_reader :gen
    attr_reader :cgen

    attr_reader :parent
    attr_reader :top_level

    # @return [String,nil]
    attr_reader :parent_uuid
    # @return [String, nil]
    attr_reader :received_uuid
  end

  class SubvolumeInfo

    # @return [Btrfs]
    attr_reader :btrfs

    # @return [AgnosticPath]
    attr_reader :subvolume_dir

    # The absolute path in the btrfs filesystem
    # @return [String]
    attr_reader :absolute_dir

    # @return [String]
    attr_reader :name

    # @return [String]
    attr_reader :uuid

    # Denotes a subvolume that's a direct parent in the snapshot's timeline.
    # I.e. [parent -> self] difference possible
    # @return [String]
    attr_reader :parent_uuid

    # Denotes the UUID of the subvolume sent by 'btrfs send'
    # @return [String]
    attr_reader :received_uuid

    # @return [String]
    attr_reader :creation_time

    # @return [Integer]
    attr_reader :subvolume_id

    # @return [Integer]
    attr_reader :generation

    # @return [Integer]
    attr_reader :gen_at_creation

    # @return [Integer]
    attr_reader :parent_id

    # @return [Integer]
    attr_reader :top_level_id

    # @return [String]
    attr_reader :flags

    # A transaction id in the sending btrfs filesystem for the `btrfs send` action.
    # Does not correspond to anything in subvolumes.
    # @return [Integer]
    attr_reader :send_transid

    # @return [String]
    attr_reader :send_time


    # The transaction of id of the start of the receive. The next transaction_id holds actual data and changes.
    # It is +1 of the subvolume's, created by btrfs receive, gen_at_creation
    # @return [Integer]
    attr_reader :receive_transid

    # @return [String]
    attr_reader :receive_time

    # @return [Array<String>]
    attr_reader :snapshots

    # @param [AgnosticPath] subvolume_dir
    def initialize(subvolume_dir)
      @subvolume_dir = subvolume_dir
      @btrfs = Btrfs.get(subvolume_dir)

      integers = Set[:subvolume_id, :generation, :gen_at_creation, :parent_id, :top_level_id, :send_transid, :receive_transid]
      btrfs.subvolume_show(subvolume_dir).each do |k, v|
        if integers.include? k.to_sym
          instance_variable_set '@'+k, Integer(v)
        else
          instance_variable_set '@'+k, v
        end
      end
    end
  end
end
