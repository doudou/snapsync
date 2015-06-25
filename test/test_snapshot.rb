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
    end
end

