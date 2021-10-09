# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'snapsync/version'

Gem::Specification.new do |spec|
  spec.name          = "snapsync"
  spec.version       = Snapsync::VERSION
  spec.authors       = ["Sylvain Joyeux"]
  spec.email         = ["sylvain.joyeux@m4x.org"]

  spec.summary       = "tool to automate backing up snapper snapshots to other medias"
  spec.homepage      = "https://github.com/doudou/snapsync"
  spec.license       = "MIT"
  spec.description   =<<-EOD
Snapsync is a tool that automates transferring snapper snapshots to
external media (USB drives ...), remote filesystems [experimental] and managing these snapshots (e.g.
timeline cleanup)
EOD

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'rexml', '~> 3.2.0'
  spec.add_dependency 'logging', '~> 2.0', ">= 2.0.0"
  spec.add_dependency 'concurrent-ruby', '~> 1.1'
  spec.add_dependency 'ruby-dbus', "~> 0.16.0"
  spec.add_dependency 'thor', "~> 1.1"
  spec.add_dependency 'uri-ssh_git', "~> 2.0.0"
  spec.add_dependency 'net-ssh', "~> 6.1.0"
  spec.add_dependency 'net-sftp', "~> 3.0.0"

  spec.add_development_dependency "bundler", "~> 2"
  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "minitest", "~> 5.0", ">= 5.7"
  spec.add_development_dependency "flexmock", "~> 2.0", ">= 2.0"
  spec.add_development_dependency "fakefs"
  spec.add_development_dependency "irb"
end
