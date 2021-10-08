module Snapsync
    # Representation of a single Snapper snapshot
    class Snapshot
        # The path to the snapshot directory
        #
        # @return [Pathname]
        attr_reader :snapshot_dir

        # @return [Btrfs]
        attr_reader :btrfs

        # The path to the snapshot's subvolume
        #
        # @return [Pathname]
        def subvolume_dir; snapshot_dir + "snapshot" end

        # The snapshot's date
        #
        # @return [DateTime]
        attr_reader :date

        # The snapshot number
        attr_reader :num

        # The snapshot's user data
        #
        # @return [Hash<String,String>]
        attr_reader :user_data

        PARTIAL_MARKER = "snapsync-partial"

        def self.partial_marker_path(snapshot_dir)
            snapshot_dir + PARTIAL_MARKER
        end

        # A file that is used to mark the snapshot has having only been
        # partially synchronized
        #
        # @return [Pathname]
        def partial_marker_path
            self.class.partial_marker_path(snapshot_dir)
        end

        # Whether this snapshot has only been partially synchronized
        def partial?
            partial_marker_path.exist?
        end

        # This snapshot's reference time
        def to_time
            date.to_time
        end

        # Whether this snapshot is one of snapsync's synchronization points
        def synchronization_point?
            user_data['snapsync']
        end

        # Whether this snapshot is one of snapsync's synchronization points for
        # the given target
        def synchronization_point_for?(target)
            user_data['snapsync'] == target.uuid
        end


        # @param [AgnosticPath] snapshot_dir
        def initialize(snapshot_dir)
            @snapshot_dir = snapshot_dir
            @btrfs = Btrfs.new(snapshot_dir.parent_mountpoint)

            if !snapshot_dir.directory?
                raise InvalidSnapshot, "#{snapshot_dir} does not exist"
            elsif !subvolume_dir.directory?
                raise InvalidSnapshot, "#{snapshot_dir}'s subvolume directory does not exist (#{subvolume_dir})"
            end

            # This loads the information and also validates that snapshot_dir is
            # indeed a snapper snapshot
            load_info
        end

        # Compute the size difference between the given snapshot and self
        #
        # This is an estimate of the size required to send this snapshot using
        # the given snapshot as parent
        #
        # @param [Snapshot] a reference snapshot, which would be used as parent
        #   in the 'send' operation
        # @return [Integer] the size in bytes of the difference between the
        #   given snapshot and the current subvolume's state
        def size_diff_from(snapshot)
            snapshot_gen = btrfs.generation_of(snapshot.subvolume_dir)
            size_diff_from_gen(snapshot_gen)
        end

        # Compute an estimate of the size of sending the whole subvolume
        #
        # @return [Integer] size in bytes
        def size
            size_diff_from_gen(0)
        end

        # @api private
        #
        # Compute the size of the 'diff' between a generation and the
        # subvolume's current state
        #
        # @param [Integer] gen the reference generation (the 'from' in the diff)
        # @return [Integer] size in bytes
        # @see size_diff_from size
        def size_diff_from_gen(gen)
            btrfs.find_new(subvolume_dir, gen).inject(0) do |size, line|
                if line =~ /len (\d+)/
                    size + Integer($1)
                else size
                end
            end
        end

        def self.each_snapshot_raw(snapshot_dir)
            return enum_for(__method__, snapshot_dir) if !block_given?
            snapshot_dir.each_child do |path|
                if path.directory? && path.basename.to_s =~ /^\d+$/
                    begin
                        snapshot = Snapshot.new(path)
                        yield(path, snapshot, nil)
                    rescue InvalidSnapshot => e
                        yield(path, nil, e)
                    end
                end
            end
        end

        # Enumerate the snapshots from the given directory
        #
        # The directory is supposed to be maintained in a snapper-compatible
        # foramt, meaning that the snapshot directory name must be the
        # snapshot's number
        def self.each(snapshot_dir, with_partial: false)
            return enum_for(__method__, snapshot_dir, with_partial: with_partial) if !block_given?
            each_snapshot_raw(snapshot_dir) do |path, snapshot, error|
                if error
                    Snapsync.warn "ignored #{path} in #{self}: #{error}"
                elsif snapshot.num != Integer(path.basename.to_s)
                    Snapsync.warn "ignored #{path} in #{self}: the snapshot reports num=#{snapshot.num} but its directory is called #{path.basename}"
                elsif !with_partial && snapshot.partial?
                    Snapsync.warn "ignored #{path} in #{self}: this is a partial snapshot"
                else
                    yield snapshot
                end
            end
        end

        # Loads snapper's info.xml, validates it and assigns the information to
        # the relevant attributes
        def load_info
            info_xml = snapshot_dir + "info.xml"
            if !info_xml.file?
                raise InvalidSnapshot, "#{snapshot_dir}/info.xml does not exist, is this really a snapper snapshot ?"
            end

            xml = REXML::Document.new(info_xml.read)
            if !xml.root
                raise InvalidInfoFile, "#{snapshot_dir}/info.xml does not look like a snapper info file (not an XML file ?)"
            elsif xml.root.name != 'snapshot'
                raise InvalidInfoFile, "#{snapshot_dir}/info.xml does not look like a snapper info file (root is not 'snapshot')"
            end

            date = xml.root.elements.to_a('date')
            if date.empty?
                raise InvalidInfoFile, "#{snapshot_dir}/info.xml does not have a date element"
            else
                @date = DateTime.parse(date.first.text)
            end

            num = xml.root.elements.to_a('num')
            if num.empty?
                raise InvalidInfoFile, "#{snapshot_dir}/info.xml does not have a num element"
            else
                @num = Integer(num.first.text)
            end

            @user_data = Hash.new
            xml.root.elements.to_a('userdata').each do |node|
                k = node.elements['key'].text
                v = node.elements['value'].text
                user_data[k] = v
            end
        end
    end
end

