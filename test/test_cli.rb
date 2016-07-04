require 'snapsync/test'
require 'snapsync/cli'
require 'fakefs/safe'

module Snapsync
    describe CLI do
        subject { CLI.new }
        
        describe "init" do
            it "reports an invalid policy with --auto" do
                subject.options = Hash[auto: true, all: true]
                e = assert_raises(ArgumentError) do
                    subject.init('name', 'dir', 'invalid')
                end
                assert(e.message =~ /synchronization policy 'invalid' does not exist/, "expected message to be about an invalid policy but is '#{e.message}'")
            end
            it "reports an invalid policy without --auto" do
                subject.options = Hash[auto: false, all: false]
                e = assert_raises(ArgumentError) do
                    subject.init('dir', 'invalid')
                end
                assert(e.message =~ /synchronization policy 'invalid' does not exist/, "expected message to be about an invalid policy but is '#{e.message}'")
            end
            it "assumes that the user meant --auto if given at least 3 arguments and the policy is valid" do
                subject.options = Hash[auto: false, all: false]
                e = assert_raises(ArgumentError) do
                    subject.init('name', 'dir', 'last')
                end
                assert(e.message =~ /--auto is not set but it seems that you provided a name/, "expected message to be about an invalid policy but is '#{e.message}'")
            end
            it "detects a missing NAME argument if --auto is given" do
                subject.options = Hash[auto: true, all: true]
                e = assert_raises(ArgumentError) do
                    subject.init('dir', 'timeline', 'day', '10')
                end
                assert(e.message =~ /--auto is set but it seems that you did not provide a name/, "expected message to be about not providing the name options, but is '#{e.message}'")
            end
            it "detects a mistakenly given NAME argument if --no-auto is given" do
                subject.options = Hash[auto: false]
                e = assert_raises(ArgumentError) do
                    subject.init('name', 'dir', 'timeline', 'day', '10')
                end
                assert(e.message =~ /--auto is not set but it seems that you provided a name/, "expected message to be about providing the name, but is '#{e.message}'")
            end
        end

        describe "auto-add" do
            attr_reader :test_dir, :subject, :conf_path, :auto_add_cmd
            before do
                @test_dir = Pathname.new(Dir.mktmpdir)
                @conf_path = (test_dir + "conf.yml")
                flexmock(CLI).new_instances.
                    should_receive(:partition_of).with(Pathname.new('/mountpoint/test_dir')).
                    and_return(['UUID', Pathname.new('test_dir')])
                @subject = CLI.new([], Hash[config_file: conf_path.to_s])
                @auto_add_cmd = CLI.all_commands['auto_add']
            end
            after do
                @test_dir.rmtree
            end

            it "creates a new config file if it does not exist" do
                auto_add_cmd.run(subject, ['test', '/mountpoint/test_dir'])
                config = YAML.load(conf_path.read)
                expected = Hash[
                    'partition_uuid' => 'UUID',
                    'path' => 'test_dir',
                    'automount' => false,
                    'name' => 'test']
                assert_equal [expected], config
            end
            it "adds new entries to an existing configuration file" do
                existing_entry = Hash[
                    'partition_uuid' => 'existing_UUID',
                    'path' => 'existing_test_dir',
                    'automount' => true,
                    'name' => 'existing_entry'] 
                conf_path.open('w') do |io|
                    YAML.dump([existing_entry], io)
                end

                auto_add_cmd.run(subject, ['test', '/mountpoint/test_dir'])
                config = YAML.load(conf_path.read)
                expected = Hash[
                    'partition_uuid' => 'UUID',
                    'path' => 'test_dir',
                    'automount' => false,
                    'name' => 'test']
                assert_equal [existing_entry, expected], config
            end
            it "sets the name of an entry that has none" do
                existing_entry = Hash[
                    'partition_uuid' => 'UUID',
                    'path' => 'test_dir',
                    'automount' => false,
                    'name' => nil] 
                conf_path.open('w') do |io|
                    YAML.dump([existing_entry], io)
                end

                auto_add_cmd.run(subject, ['test', '/mountpoint/test_dir'])
                config = YAML.load(conf_path.read)
                assert_equal [existing_entry.merge('name' => 'test')], config
            end
            it "does not update the name of an existing entry that has one" do
                existing_entry = Hash[
                    'partition_uuid' => 'UUID',
                    'path' => 'test_dir',
                    'automount' => false,
                    'name' => 'test'] 
                conf_path.open('w') do |io|
                    YAML.dump([existing_entry], io)
                end

                auto_add_cmd.run(subject, ['changed', '/mountpoint/test_dir'])
                config = YAML.load(conf_path.read)
                assert_equal [existing_entry], config
            end

            it "updates the automount flag of an existing entry" do
                existing_entry = Hash[
                    'partition_uuid' => 'UUID',
                    'path' => 'test_dir',
                    'automount' => true,
                    'name' => 'test'] 
                conf_path.open('w') do |io|
                    YAML.dump([existing_entry], io)
                end

                subject = CLI.new([], Hash[config_file: conf_path.to_s, automount: false])
                auto_add_cmd.run(subject, ['test', '/mountpoint/test_dir'])
                config = YAML.load(conf_path.read)
                assert_equal [existing_entry.merge('automount' => false)], config

                subject = CLI.new([], Hash[config_file: conf_path.to_s, automount: true])
                auto_add_cmd.run(subject, ['test', '/mountpoint/test_dir'])
                config = YAML.load(conf_path.read)
                assert_equal [existing_entry.merge('automount' => true)], config
            end
        end
    end
end

