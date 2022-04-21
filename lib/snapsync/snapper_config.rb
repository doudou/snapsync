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
        # @return [String]
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
        def each_snapshot(&block)
            Snapshot.each(snapshot_dir, &block)
        end

        def self.default_config_dir
            Pathname.new('/etc/snapper/configs')
        end

        # Enumerates the valid snapper configurations present in a directory
        def self.each_in_dir(path = default_config_dir)
            path.each_entry do |config_file|
                config_name = config_file.to_s
                config_file = path + config_file
                next if !config_file.file?
                begin
                    config = SnapperConfig.load(config_file)
                rescue Interrupt
                    raise
                rescue Exception => e
                    Snapsync.warn "cannot load #{config_file}: #{e.message}"
                    e.backtrace.each do |line|
                        Snapsync.debug "  #{line}"
                    end
                    next
                end

                yield(config)
            end
        end

        # Create a new snapshot
        #
        # @return [Snapshot]
        def create(type: 'single', description: '', user_data: Hash.new)
            user_data = user_data.map { |k,v| "#{k}=#{v}" }.join(",")
            snapshot_id = IO.popen(["snapper", "-c", name, "create",
                     "--type", type,
                     "--print-number",
                     "--description", description,
                     "--userdata", user_data]) do |io|
                Integer(io.read.strip)
            end
            Snapshot.new(snapshot_dir + snapshot_id.to_s)
        end

        # Delete one of this configuration's snapshots
        def delete(snapshot)
            system("snapper", "-c", name, "delete", snapshot.num.to_s)
        end

        def cleanup
            Snapsync.debug "SnapperConfig.cleanup"
            system('snapper', '-c', name, 'cleanup', 'all')
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
            if @subvolume
                @subvolume = Pathname.new(subvolume)
            end
        end
    end
end

