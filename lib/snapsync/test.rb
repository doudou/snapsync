# simplecov must be loaded FIRST. Only the files required after it gets loaded
# will be profiled !!!
if ENV['TEST_ENABLE_COVERAGE'] == '1'
    begin
        require 'simplecov'
        SimpleCov.start
    rescue LoadError
        require 'snapsync'
        Snapsync.warn "coverage is disabled because the 'simplecov' gem cannot be loaded"
    rescue Exception => e
        require 'snapsync'
        Snapsync.warn "coverage is disabled: #{e.message}"
    end
end

require 'minitest/autorun'
require 'snapsync'
require 'flexmock/minitest'
require 'minitest/spec'

if ENV['TEST_ENABLE_PRY'] != '0'
    begin
        require 'pry'
    rescue Exception
        Snapsync.warn "debugging is disabled because the 'pry' gem cannot be loaded"
    end
end

module Snapsync
    # This module is the common setup for all tests
    module SelfTest
        def setup
            @tempdirs = Array.new
            Snapsync._mountpointCache = {}
            Snapsync::Btrfs._mountpointCache = {}
            super
            # Setup code for all the tests
        end

        def teardown
            @tempdirs.each do |dir|
                FileUtils.rm_rf dir
            end
            super
            # Teardown code for all the tests
        end

        def make_tmpdir
            @tempdirs << Dir.mktmpdir
        end
    end
end

Minitest::Test.include Snapsync::SelfTest

