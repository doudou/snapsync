# Snapsync

A synchronization tool for snapper

This gem implements snapper-based backup, by allowing you to synchronize a
snapper snapshot directory to a different location using btrfs send and
receive.

It can be used in two modes:
 - in manual mode, you run snapsync 

## Installation

You need to make sure that you've installed Ruby's bundler. On Ubuntu, run
    $ apt install bundler

Then, the following will install snapsync in /opt/snapsync
    
    $ wget https://raw.githubusercontent.com/doudou/snapsync/master/install.sh
    $ sh install.sh

The script will use sudo to get root rights when required. Add /opt/snapsync/bin
to your PATH if you want to use 'snapsync' as-is. Otherwise, you will have to
refer to /opt/snapsync/bin/snapsync explicitely. If it seems that you are using
systemd, the script also installs snapsync's systemd service file into the
system, enables and starts it.

## Usage

The most common usage of snapsync is to define a remote target (for instance, a
USB drive) to which the snapshots should be copied. Mount the drive manually
first and do

    $ snapsync init /path/to/the/drive/snapsync

This will create snapsync targets for each of the snapper configurations
currently present on the system (i.e. if there is a 'home' and 'root'
configurations, it will create /path/to/the/drive/snapsync/root and
/path/to/the/drive/snapsync/auto). The 'default' synchronization policy is used
(see below for other options).

If you use systemd, the background systemd job will from now on synchronize the
new target whenever it is present (i.e. as soon as it is plugged in). If you
don't, or if you decided to disable the service's auto-start, run (and keep on
running)

    $ snapsync auto-sync

to achieve the same result.

## Synchronization and cleanup policies

snapsync offers multiple synchronization-and-cleanup policies for targets. These
policies determine what to copy to the target, as well as what to keep on the
target.

The default policy copies everything and removes nothing. It's great at the
beginning, but is obviously not a very good long-term strategy ;-)

Policies can be set at initialization time by passing additional arguments to
'snapsync init', or later with 'snapsync policy'. Run
'snapsync help init' and 'snapsync help policy' for more information.

## Manual usage

If you prefer using snapsync manually, or use different automation that the one
provided by auto-sync, run 'snapsync' without arguments to get all the
possibilities. Targets have configuration files that allow to fine-tune
snapsync's automated behaviour to that effect.

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/snapsync.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

