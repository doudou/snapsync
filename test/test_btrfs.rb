require 'snapsync/test'

$btrfs_subvolume_table = '
ID 787 gen 2054710 cgen 1199657 parent 5 top level 5 parent_uuid -                                    received_uuid -                                    uuid ee83e78f-79d7-744d-abf7-bb791836bc53 path root
ID 788 gen 2054711 cgen 1199662 parent 787 top level 787 parent_uuid -                                    received_uuid -                                    uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 path home
ID 793 gen 2054620 cgen 1199733 parent 788 top level 788 parent_uuid -                                    received_uuid -                                    uuid ff2000c4-83c2-6648-a1b1-aeb620546b44 path home/.snapshots
ID 5321 gen 2052582 cgen 2041842 parent 793 top level 793 parent_uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 received_uuid -                                    uuid 222d3962-b470-4040-8706-6843ac5b06ea path home/.snapshots/2012/snapshot
ID 5340 gen 2052582 cgen 2043837 parent 793 top level 793 parent_uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 received_uuid -                                    uuid d129e438-e09a-ad4b-a99a-088b9e29dc85 path home/.snapshots/2031/snapshot
ID 5364 gen 2052582 cgen 2046633 parent 793 top level 793 parent_uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 received_uuid -                                    uuid b4343230-7f4f-7b42-b04b-e0926a5dcc3f path home/.snapshots/2055/snapshot
ID 5393 gen 2052582 cgen 2051464 parent 793 top level 793 parent_uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 received_uuid -                                    uuid fe683b96-4e63-f440-8e59-d62a7d6e10a1 path home/.snapshots/2083/snapshot
ID 5407 gen 2054090 cgen 2054089 parent 793 top level 793 parent_uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 received_uuid -                                    uuid a46d4c70-c110-cb4b-8af3-d7907009136c path home/.snapshots/2097/snapshot
ID 5408 gen 2054207 cgen 2054206 parent 793 top level 793 parent_uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 received_uuid -                                    uuid a102f527-3283-dc45-a5c5-3bac57155562 path home/.snapshots/2098/snapshot
ID 5409 gen 2054437 cgen 2054436 parent 793 top level 793 parent_uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 received_uuid -                                    uuid 7aed84dd-64e4-3b4e-8fc4-35143e5d3dbf path home/.snapshots/2099/snapshot
ID 5410 gen 2054577 cgen 2054576 parent 793 top level 793 parent_uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 received_uuid -                                    uuid 708ec4a0-aab4-e248-a1ad-c09be50f8b96 path home/.snapshots/2100/snapshot
ID 5411 gen 2054620 cgen 2054619 parent 793 top level 793 parent_uuid c3e9ee79-07b2-fb43-b152-4eb430445ca5 received_uuid -                                    uuid d48cb1d8-78ed-6948-9e99-ef1cef48f405 path home/.snapshots/2101/snapshot
'

def build_readable(text)
    r, w = IO.pipe
    w.write(text.force_encoding('UTF-8'))
    w.flush
    w.close

    r
end

module Snapsync
    describe Btrfs do
        before do
            flexmock(Pathname).new_instances.should_receive(:findmnt).and_return(Pathname.new '/')
        end

        describe '.read_subvolume_table' do
            it "is able to part btrfs subvolume table" do
                r2 = build_readable($btrfs_subvolume_table)
                flexmock(IO).should_receive(:popen).and_yield(r2).once

                btrfs = Btrfs.get(Pathname.new '/')
                assert_equal $btrfs_subvolume_table.lines.length, btrfs.subvolume_table.length
            end
        end

        describe 'methods' do
            before do
                flexmock(Btrfs).new_instances.should_receive(:read_subvolume_table)
            end

            describe ".run" do
                it "sanitizes the btrfs subcommand output" do
                    r3 = build_readable("\xFF\n\xFF")

                    flexmock(IO).should_receive(:popen).and_yield(r3)
                    assert_equal "\uFFFD\n\uFFFD", Btrfs.get(Snapsync::path '/').run
                end
            end

            describe ".generation_of" do
                it "extracts the subvolume current generation" do
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
    end
end

