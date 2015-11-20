require 'snapsync/test'
require 'snapsync/cli'
require 'fakefs/safe'

module Snapsync
    describe CLI do
        subject { CLI.new }
        
        describe "init" do
            it "raises without creating anything if the policy is invalid" do
                e = assert_raises(ArgumentError) do
                    subject.init('name', 'dir', 'invalid')
                end
                assert(e.message =~ /invalid policy/, "expected message to be about an invalid policy but is '#{e.message}'")
            end
            it "detects a missing NAME argument if --auto is given" do
                subject.options = Hash[auto: true]
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
    end
end

