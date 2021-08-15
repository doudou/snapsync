module Snapsync
    class PartitionsMonitor
        attr_reader :udisk

        attr_reader :dirty

        attr_reader :monitored_partitions
        attr_reader :known_partitions

        def initialize
            dbus = DBus::SystemBus.instance
            @udisk = dbus.service('org.freedesktop.UDisks2')
            udisk.introspect

            @dirty = Concurrent::AtomicBoolean.new(false)
            # udisk.on_signal('InterfacesAdded') do
            #     dirty!
            # end
            # udisk.on_signal('InterfacesRemoved') do
            #     dirty!
            # end

            @monitored_partitions = Set.new
            @known_partitions = Hash.new
        end

        def monitor_for(partition_uuid)
            monitored_partitions << partition_uuid.to_str
        end

        def partition_of(dir)
            rel = Pathname.new("")
            dir = dir.expand_path
            while !dir.mountpoint?
                rel = dir.basename + rel
                dir = dir.dirname
            end

            # Collect partitions list from udisk
            parts = []
            each_partition_with_filesystem do |name, dev|
                partition = dev['org.freedesktop.UDisks2.Block']
                uuid = partition['IdUUID']
                fs = dev['org.freedesktop.UDisks2.Filesystem']
                mount_points = fs['MountPoints'].map do |str|
                    str[0..-2].pack("U*")
                end
                parts.push([name, dev, uuid, mount_points])
            end

            # Find any partition that is a parent of the folder we are looking at
            loop do
                parts.each do |name, dev, uuid, mount_points|
                    if mount_points.include?(dir.to_s)
                        return uuid, rel
                    end
                end
                raise ArgumentError, "cannot guess the partition UUID of the mountpoint #{dir} for #{dir + rel}" if dir.to_s == '/'
                dir = dir.parent
            end
        end

        def dirty!
            dirty.set
        end

        def dirty?
            dirty.set?
        end

        def partition_uuid_for_dir(dir)
            dir = dir.expand_path
            # Find the dir's mountpoint
            while !dir.mountpoint?
                dir = dir.parent
            end
            dir = dir.to_s

            each_partition_with_filesystem.find do |name, dev|
                fs = dev['org.freedesktop.UDisks2.Filesystem']
                mp = fs['MountPoints']
                # .map { |str| Pathname.new(str) }
                mp.include?(dir)
            end
        end

        def poll
            udisk.introspect
            dirty.make_false

            all = Hash.new
            each_partition_with_filesystem do |name, dev|
                partition = dev['org.freedesktop.UDisks2.Block']
                uuid = partition['IdUUID']

                if monitored_partitions.include?(uuid)
                    all[uuid] = dev['org.freedesktop.UDisks2.Filesystem']
                end
            end

            added = Hash.new
            (all.keys - known_partitions.keys).each do |uuid|
                fs = added[uuid] = all[uuid]
                emit_added(uuid, fs)
            end
            removed = (known_partitions.keys - all.keys)
            removed.each { |uuid| emit_removed(uuid) }

            @known_partitions = all
            return added, removed
        end

        def emit_added(uuid, fs)
        end

        def emit_removed(uuid)
        end

        # Yields the udev objects representing block devices that support an
        # underlying filesystem
        #
        # @yieldparam [String] the block device name (e.g. sda3)
        # @yieldparam the block device's udev object
        def each_partition_with_filesystem
            return enum_for(__method__) if !block_given?
            udisk.root['org']['freedesktop']['UDisks2']['block_devices'].each do |device_name, _|
                dev = udisk.object("/org/freedesktop/UDisks2/block_devices/#{device_name}")
                if dev['org.freedesktop.UDisks2.Block'] && dev['org.freedesktop.UDisks2.Filesystem']
                    yield(device_name, dev)
                end
            end
        end
    end
end
