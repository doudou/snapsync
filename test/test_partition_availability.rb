require 'snapsync/test'

module Snapsync
    describe PartitionsMonitor do
        subject { PartitionsMonitor.new }

        describe "#partition_of" do
            attr_reader :path, :expanded_path, :mount_point
            before do
                @path = Pathname.new("b")
                @expanded_path = Pathname.new("/a/b")
                @mount_point = Pathname.new("/a")

                flexmock(path).should_receive(:expand_path).and_return(expanded_path)
                flexmock(expanded_path).should_receive(:dirname).and_return(mount_point)
                flexmock(mount_point).should_receive(:mountpoint?).and_return(true)
            end

            it "returns the UUID, mountpoint, relative path of the partition matching the mountpoint" do
                dev = Hash[
                    'org.freedesktop.UDisks2.Block' => Hash[
                        'IdUUID' => 'TestUUID'
                    ],
                    'org.freedesktop.UDisks2.Filesystem' => Hash[
                        'MountPoints' => ["/a".unpack("U*") + [0]]
                    ]
                ]
                flexmock(subject).should_receive(:each_partition_with_filesystem).
                    and_yield("", dev)
                assert_equal ['TestUUID', Pathname.new('/a'), Pathname.new("b")], subject.partition_of(path)
            end

            it "raises ArgumentError if we can't find the mount point in UDisks" do
                flexmock(subject).should_receive(:each_partition_with_filesystem).and_yield(['name', Hash[
                    'org.freedesktop.UDisks2.Block' => Hash['IdUUID' => 'test'],
                    'org.freedesktop.UDisks2.Filesystem' => Hash['MountPoints' => ["/test".unpack("U*") + [0]]]
                    ]])
                error = assert_raises(ArgumentError) do
                    subject.partition_of(path)
                end
                assert_match /cannot guess the partition UUID of the mountpoint \/a for \/a\/b/, error.message
            end
        end

        describe "#each_partition_with_filesystem" do
            it "discovers the available partitions" do
                # We don't *know* the available partitions, and I don't want to
                # setup a full mock environment for such a small project ...
                # Check that we have some partitions
                partitions = subject.each_partition_with_filesystem.to_a
                assert !partitions.empty?
                found_root_mountpoint = false
                partitions.each do |name, dev|
                    assert name.respond_to?(:to_str)
                    assert dev['org.freedesktop.UDisks2.Block']['IdUUID']
                    assert(fs = dev['org.freedesktop.UDisks2.Filesystem'])
                    mount_points = fs['MountPoints'].map do |str|
                        str[0..-2].pack("U*")
                    end
                    if mount_points.include?('/')
                        found_root_mountpoint = true
                    end
                end
                assert found_root_mountpoint, "could not find the mountpoint for root"
            end
        end
    end
end

