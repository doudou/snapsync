module Snapsync
    # A snapper configuration
    class SnapperConfig
        # The configuration name
        attr_reader :name

        # Path to the subvolume
        #
        # @return [Pathname]
        attr_reader :subvolume

        # The filesystem type
        attr_reader :fstype

        def initialize(name)
            @name = name.to_str
            @subvolume, @fstype = nil
        end

        # The directory containing the snapshots
        def snapshot_dir
            subvolume + ".snapshots"
        end

        # Enumerate the valid snapshots in this configuration
        #
        # @yieldparam [Snapshot] snapshot
        def each_snapshot
            return enum_for(__method__) if !block_given?
            snapshot_dir.each_child do |path|
                if path.directory? && path.basename.to_s =~ /^\d+$/
                    begin
                        snapshot = Snapshot.new(path)
                    rescue InvalidSnapshot => e
                        Snapsync.warn "ignored #{path} in #{self}: #{e}"
                    end
                    if snapshot
                        if snapshot.num != Integer(path.basename.to_s)
                            Snapsync.warn "ignored #{path} in #{self}: the snapshot reports num=#{snapshot.num} but its directory is called #{path.basename}"
                        else
                            yield snapshot
                        end
                    end
                end
            end
        end

        # Create a SnapperConfig object from the data in a configuration file
        #
        # @param [#readlines] path the file
        # @param [String] name the configuration name
        # @return [SnapperConfig]
        # @raise (see #load)
        def self.load(path, name: path.basename.to_s)
            config = new(name)
            config.load(path)
            config
        end

        # @api private
        #
        # Extract the key and value from a snapper configuration file
        #
        # @return [(String,String)] the key and value pair, or nil if it is an
        #   empty or comment line
        def parse_line(line)
            line = line.strip.gsub(/#.*/, '')
            if !line.empty?
                if line =~ /^(\w+)="?([^"]*)"?$/
                    return $1, $2
                else
                    raise ArgumentError, "cannot parse #{line}"
                end
            end
        end

        # Load the information from a configuration file into this object
        #
        # @see SnapperConfig.load
        def load(path)
            path.readlines.each do |line|
                key, value = parse_line(line)
                case key
                when NilClass then next
                else
                    instance_variable_set("@#{key.downcase}", value)
                end
            end
        end
    end
end

