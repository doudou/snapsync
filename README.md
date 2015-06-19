# Snapsync

A synchronization tool for snapper

This gem implements snapper-based backup, by allowing you to synchronize a
snapper snapshot directory to a different location. It uses btrfs send and
receive to achieve it

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'snapsync'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install snapsync

## Usage

TODO: Write usage instructions here

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/snapsync.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

