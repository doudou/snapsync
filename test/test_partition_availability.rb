require 'snapsync/test'

module Snapsync
    describe PartitionsMonitor do
        subject { PartitionsMonitor.new }

        describe "#each_partition_with_filesystem" do
            it "discovers the available partitions" do
                # We don't *know* the available partitions, and I don't want to
                # setup a full mock environment for such a small project ...
                # Check that we have some partitions
                partitions = subject.each_partition_with_filesystem.to_a
                assert !partitions.empty?
                partitions.each do |name, dev|
                    assert name.respond_to?(:to_str)
                    assert dev['org.freedesktop.UDisks2.Partition']
                end
            end
        end
    end
end

