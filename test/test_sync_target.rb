require 'snapsync/test'
require 'fakefs/safe'

module Snapsync
    describe SyncTarget do
        subject { SyncTarget.new }

        before do
            FakeFS.activate!
        end
        after do
            FakeFS.deactivate!
            FakeFS::FileSystem.clear
        end

        let(:path) { Pathname.new('/path') }

        it "raises ArgumentError if the target directory does not exist" do
            assert_raises(ArgumentError) do
                SyncTarget.new(path)
            end
        end
        it "raises ArgumentError if the target directory exists but is not a directory" do
            FileUtils.touch '/path'
            assert_raises(ArgumentError) do
                SyncTarget.new(path)
            end
        end
        it "creates the configuration if #read_config raises NoUUIDError and create_if_needed is true" do
            path.mkpath
            flexmock(SyncTarget).should_receive(:read_config).and_raise(SyncTarget::NoUUIDError)
            created_target   = SyncTarget.new(path, create_if_needed: true)
            yaml = YAML.load((path + "snapsync.config").read)
            assert_equal created_target.uuid, yaml['uuid']
        end
        it "raises if #read_config raises NoUUIDError and create_if_needed is false" do
            path.mkpath
            flexmock(SyncTarget).should_receive(:read_config).and_raise(SyncTarget::NoUUIDError)
            assert_raises(SyncTarget::NoUUIDError) { SyncTarget.new(path, create_if_needed: false) }
        end
        it "is robust to an empty config file" do
            path.mkpath
            (path + "snapsync.config").open('w').close
            assert_raises(SyncTarget::NoUUIDError) { SyncTarget.new(path, create_if_needed: false) }
        end
        it "loads its config from an existing config file" do
            path.mkpath
            (path + "snapsync.config").open('w') do |io|
                YAML.dump(Hash['uuid' => '2bd2ec17-565c-4e8b-b650-9ec77926fbc1'])
            end
            flexmock(SyncTarget).should_receive(:read_config).and_raise(SyncTarget::NoUUIDError)
            assert_raises(SyncTarget::NoUUIDError) { SyncTarget.new(path, create_if_needed: false) }
        end

        it "raises InvalidConfiguration if changing to an invalid policy" do
            path.mkpath
            target = SyncTarget.new(path)
            assert_raises(InvalidConfiguration) do
                target.change_policy('invalid', Hash.new)
            end
        end
    end
end

