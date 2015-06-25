module Snapsync
    # Representation of a single Snapper snapshot
    class Snapshot
        # The path to the snapshot directory
        #
        # @return [Pathname]
        attr_reader :snapshot_dir

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

        def initialize(snapshot_dir)
            @snapshot_dir = snapshot_dir

            if !snapshot_dir.directory?
                raise InvalidSnapshot, "#{snapshot_dir} does not exist"
            elsif !subvolume_dir.directory?
                raise InvalidSnapshot, "#{snapshot_dir}'s subvolume directory does not exist (#{subvolume_dir})"
            end

            # This loads the information and also validates that snapshot_dir is
            # indeed a snapper snapshot
            load_info
        end

        # Loads snapper's info.xml, validates it and assigns the information to
        # the relevant attributes
        def load_info
            info_xml = snapshot_dir + "info.xml"
            if !info_xml.file?
                raise InvalidSnapshot, "#{snapshot_dir}/info.xml does not exist, is this really a snapper snapshot ?"
            end

            xml = REXML::Document.new(info_xml.read)
            if xml.root.name != 'snapshot'
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
        end
    end
end

