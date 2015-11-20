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
external media (USB drives ...) and managing these snapshots (e.g.
timeline cleanup)
EOD

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'logging', '~> 2.0', ">= 2.0.0"
  spec.add_dependency 'concurrent-ruby', '~> 0.9.0', '>= 0.9'
  spec.add_dependency 'ruby-dbus', "~> 0.11.0", ">= 0.11"
  spec.add_dependency 'thor', "~> 0.19.0", ">= 0.19.1"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0", ">= 5.7"
  spec.add_development_dependency "flexmock", "~> 1.3", ">= 1.3.3"
  spec.add_development_dependency "fakefs"
end
