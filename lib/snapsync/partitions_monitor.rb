module Snapsync
    class PartitionsMonitor
        attr_reader :udisk

        attr_reader :dirty

        # @return [Set<String>]
        attr_reader :monitored_partitions
        # @return [Hash<String, Dev>]
        attr_reader :known_partitions

        # @return [Hash<String, DBus::ProxyObjectInterface>]
        attr_reader :partition_table

        # @param [RemotePathname] machine Remote machine to connect to
        def initialize(machine = nil)
            if machine.nil?
                dbus = DBus::SystemBus.instance
            else
                sock_path = '/tmp/snapsync_%04d_remote.sock' % rand(10000)


                ready = Concurrent::AtomicBoolean.new(false)
                @ssh_thr = Thread.new do
                    machine.dup_ssh do |ssh|
                        @ssh = ssh
                        if Snapsync.SSH_DEBUG
                            log = Logger.new(STDOUT)
                            log.level = Logger::DEBUG
                            ssh.logger = log
                            ssh.logger.sev_threshold=Logger::Severity::DEBUG
                        end
                        ssh.forward.local_socket(sock_path, '/var/run/dbus/system_bus_socket')
                        ObjectSpace.define_finalizer(@ssh, proc {
                            File.delete sock_path
                        })
                        ready.make_true
                        ssh.loop { true }
                    end
                end
                while ready.false?
                    sleep 0.001
                end

                dbus = DBus::RemoteBus.new "unix:path=#{sock_path}"
            end
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
            @partition_table = Hash.new
        end

        # @param [DBus::ProxyObjectInterface] fs
        # @return [Array<String>]
        def mountpoints(fs)
            raise "Not mounted?" if fs.nil?
            mount_points = fs['MountPoints'].map do |str|
                str[0..-2].pack("U*")
            end
            return mount_points
        end

        def mountpoint_of_uuid(partition_uuid)
            mounts = mountpoints(known_partitions[partition_uuid])
            raise "Ambiguous mountpoints: #{mounts}" if mounts.length > 1
            mounts[0]
        end

        def monitor_for(partition_uuid)
            monitored_partitions << partition_uuid.to_str
        end

        # @return [String, Snapsync::Path, Pathname] uuid dir rel
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
                parts.push([name, uuid, mount_points])
            end

            # Find any partition that is a parent of the folder we are looking at
            parts.each do |name, uuid, mount_points|
                if mount_points.include?(dir.path_part)
                    return uuid, dir, rel
                end
            end
            raise ArgumentError, "cannot guess the partition UUID of the mountpoint #{dir} for #{dir + rel}"
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
                    fs = dev['org.freedesktop.UDisks2.Filesystem']

                    # If it is a btrfs raid, it will have multiple partitions with the same uuid, but only one will be
                    # mounted.
                    next if all.has_key?(uuid) and all[uuid]['MountPoints'].size > 0

                    all[uuid] = fs
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
                if dev.has_iface?('org.freedesktop.UDisks2.Block') && dev.has_iface?('org.freedesktop.UDisks2.Filesystem')
                    yield(device_name, dev)
                end
            end
        end
    end
end
