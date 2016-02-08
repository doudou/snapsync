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
    #
    # It should be included in the toplevel describe blocks
    #
    # @example
    #   require 'snapsync/test'
    #   describe Snapsync do
    #     include Snapsync::SelfTest
    #   end
    #
    module SelfTest
        if defined? FlexMock
            include FlexMock::ArgumentTypes
            include FlexMock::MockContainer
        end

        def setup
            # Setup code for all the tests
        end

        def teardown
            if defined? FlexMock
                flexmock_teardown
            end
            super
            # Teardown code for all the tests
        end
    end
end

Minitest::Test.include Snapsync::SelfTest


