require 'snapsync/test'

module Snapsync
    describe Btrfs do
        describe ".run" do
            it "sanitizes the btrfs subcommand output" do
                r, w = IO.pipe
                w.write("\xFF\n\xFF".force_encoding("UTF-8"))
                w.flush
                w.close
                flexmock(IO).should_receive(:popen).and_yield(r)
                assert_equal "\uFFFD\n\uFFFD", Btrfs.get(Snapsync::path '/').run
            end
        end
    end

    describe ".generation_of" do
        it "extracts the subvoume current generation" do
            btrfs = Btrfs.get(Snapsync::path '/')
            flexmock(btrfs).should_receive(:run).
                with('subvolume', 'show', '/path/to/subvolume').
                and_return <<-END_OF_OUTPUT
/
        Name:                   @
        UUID:                   2a965269-a775-284b-ac1f-880b0046229b
        Parent UUID:            7a6166ac-2ccc-a749-8ea0-16896476c9ab
        Received UUID:          -
        Creation time:          2016-03-21 19:57:16 -0300
        Subvolume ID:           5802
        Generation:             526059
        Gen at creation:        286783
        Parent ID:              5
        Top level ID:           5
        Flags:                  -
        Snapshot(s):
                                @recovery
                                .snapshots/4077/snapshot
                                .snapshots/4290/snapshot
                                .snapshots/4300/snapshot
		END_OF_OUTPUT

	        assert_equal 526059, btrfs.generation_of(Pathname.new('/path/to/subvolume'))
        end

        it "raises UnexpectedBtrfsOutput if the output does not contain a Generation line" do
            btrfs = Btrfs.get(Snapsync::path '/')
            flexmock(btrfs).should_receive(:run).
                and_return ""
            assert_raises(Btrfs::UnexpectedBtrfsOutput) do
                btrfs.generation_of(Pathname.new('/path/to/subvolume'))
            end
        end
    end
end

