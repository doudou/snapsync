require 'snapsync/test'

module Snapsync
    describe SnapperConfig do
        def config_file
            Pathname.new(__FILE__).dirname + "configs" + "home"
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
    end
end
