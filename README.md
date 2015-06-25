# Snapsync

A synchronization tool for snapper

This gem implements snapper-based backup, by allowing you to synchronize a
snapper snapshot directory to a different location. It uses btrfs send and
receive to achieve it

## Installation

Run

    $ gem install snapsync

## Usage

To synchronize the snapshots of the 'home' snapper configuration to an existing
directory, run

    $ snapsync home /media/backup

Snapsync uses sudo to get root access. If you wish to not run it as root, you
will need to change the snapper permissions to give read access to all the
snapper shapshots, e.g.

    $ chmod go+rx /.snapshots
    $ chmod go+r /.snapshots/*/info.xml

In addition, sudo will ask for your root password when applicable. If you wish
to fully automate, you will need to allow snapsync to run the btrfs tool without
password in the sudoers file.

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/snapsync.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

