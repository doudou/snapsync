module Snapsync
    module Async
        class MonitorPartitionAvailability
            attr_reader :udisk

            attr_reader :dirty

            attr_reader :known_partitions

            def initialize
                dbus = DBus::SystemBus.instance
                @udisk = dbus.service('org.freedesktop.UDisks2')
                udisk.introspect

                @dirty = Concurrent::AtomicBoolean.new(false)
                udisk.on_signal('InterfacesAdded') do
                    dirty!
                end
                udisk.on_signal('InterfacesRemoved') do
                    dirty!
                end

                @known_partitions = Set.new
            end

            def monitor_for(partition_uuid)
                monitored_partitions << partition_uuid
            end

            def dirty!
                dirty.set
            end

            def dirty?
                dirty.set?
            end

            def poll
                udisk.introspect
                dirty.reset

                found = each_partition_with_filesystem.map do |name, dev|
                    partition = dev['org.freedesktop.UDisks2.Partition']
                    uuid = partition['UUID']

                    if monitored_partitions.include?(uuid)
                        if !known_partitions.include?(uuid)
                            fs = dev['org.freedesktop.UDisks2.Filesystem']
                            fs.introspect
                            emit_added(uuid, fs)
                        end
                        uuid
                    end
                end.compact.to_set

                (known_partitions - found).each do |uuid|
                    emit_removed uuid
                end
                @known_partitions = uuid
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
                    if dev['org.freedesktop.UDisks2.Partition'] && dev['org.freedesktop.UDisks2.Filesystem']
                        yield(device_name, dev)
                    end
                end
            end
        end
    end
end
