require 'snapsync/test'

module Snapsync
    describe Snapshot do
        def stub_snapshots_dir
            Pathname.new(__FILE__).dirname + "snapshots"
        end

        it "raises InvalidSnapshot if the directory does not exist" do
            assert_raises(InvalidSnapshot) { Snapshot.new(Pathname.new("/does_not_exist")) }
        end
        it "raises InvalidSnapshot if the directory does not contain a info.xml file" do
            assert_raises(InvalidSnapshot) { Snapshot.new(stub_snapshots_dir + "info_xml_does_not_exist") }
        end
        it "raises InvalidInfoFile if the info.xml file does not have a 'snapshot' root" do
            assert_raises(InvalidInfoFile) { Snapshot.new(stub_snapshots_dir + "info_xml_no_snapshot_root") }
        end
        it "raises InvalidInfoFile if the info.xml file does not have a 'snapshot/num' element" do
            assert_raises(InvalidInfoFile) { Snapshot.new(stub_snapshots_dir + "info_xml_no_num_element") }
        end
        it "sets the num attribute from the information in the file" do
            assert_equal 1, Snapshot.new(stub_snapshots_dir + "valid").num
        end
        it "raises InvalidInfoFile if the info.xml file does not have a 'snapshot/date' element" do
            assert_raises(InvalidInfoFile) { Snapshot.new(stub_snapshots_dir + "info_xml_no_date_element") }
        end
        it "sets the date attribute from the information in the file" do
            assert_equal DateTime.parse('2015-06-18 18:17:01'), Snapshot.new(stub_snapshots_dir + "valid").date
        end
        it "raises InvalidSnapshot if the subvolume directory does not exist" do
            assert_raises(InvalidSnapshot) { Snapshot.new(stub_snapshots_dir + "no_subvolume_directory") }
        end
        it "reads the user data" do
            assert_equal Hash['important' => 'yes', 'test' => 'blabla'],
                Snapshot.new(stub_snapshots_dir + "valid").user_data
        end

        describe "#size_diff_from_gen" do
            attr_reader :snapshot, :btrfs
            before do
                @snapshot = Snapshot.new(stub_snapshots_dir + "valid")
            end

            it "accumulates the length of each difference record" do
                flexmock(snapshot.btrfs).should_receive(:find_new).
                    with(stub_snapshots_dir + "valid" + "snapshot", 42).
                    once.and_return [
                        "inode 8992834 file offset 0 len 10 disk start 54989 offset 0 gen 32948 flags NONE fake/entry/",
                        "inode 8992834 file offset 0 len 33 disk start 54254 offset 0 gen 509547 flags NONE another/fake/entry/"]

                assert_equal 43, snapshot.size_diff_from_gen(42)
            end

            it "ignores non-matching lines" do
                flexmock(snapshot.btrfs).should_receive(:find_new).
                    with(stub_snapshots_dir + "valid" + "snapshot", 42).
                    once.and_return [
                        "something completely else",
                        "inode 8992834 file offset 0 len 33 disk start 54254 offset 0 gen 509547 flags NONE another/fake/entry/"]
                assert_equal 33, snapshot.size_diff_from_gen(42)
            end
        end
    end
end

