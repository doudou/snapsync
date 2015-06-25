require 'snapsync/test'

module Snapsync
    describe SnapperConfig do
        def config_file
            Pathname.new(__FILE__).dirname.expand_path + "configs" + "home"
        end
        def snapshots_dir
            Pathname.new(__FILE__).dirname.expand_path + "snapshots" + "snapshots_dir"
        end

        describe ".load" do
            it "returns a SnapperConfig object" do
                assert_kind_of SnapperConfig, SnapperConfig.load(config_file)
            end
            it "sets the fields according to the values in the file" do
                config = SnapperConfig.load(config_file)
                assert_equal 'btrfs', config.fstype
            end
        end

        describe "#each_snapshot" do
            subject { SnapperConfig.new('test') }

            it "enumerates valid snapshots" do
                flexmock(subject).should_receive(:snapshot_dir).
                    and_return(snapshots_dir + "valid")
                snapshots = subject.each_snapshot.to_a
                assert_equal 1, snapshots.size
                s = snapshots.first
                assert_equal snapshots_dir + "valid" + "1", s.snapshot_dir
                assert_equal 1, s.num
                assert_equal DateTime.parse("2015-06-18 18:17:01"), s.date
            end
            it "issues a warnings for invalid snapshots" do
                flexmock(Snapsync).should_receive(:warn).with(/2/).once
                flexmock(subject).should_receive(:snapshot_dir).
                    and_return(snapshots_dir + "with_invalid_snapshot")
                assert_equal 1, subject.each_snapshot.to_a.size
            end
            it "validates that the directory name matches the snapshot's 'num' field" do
                flexmock(Snapsync).should_receive(:warn).with(/2/).once
                flexmock(subject).should_receive(:snapshot_dir).
                    and_return(snapshots_dir + "with_mismatching_num")
                assert_equal 1, subject.each_snapshot.to_a.size
            end
        end
    end
end
