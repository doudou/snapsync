require 'pathname'
require 'logging'
require "snapsync/version"
require "snapsync/snapper_config"

module Logging
    module Installer
        def logger
            @logger ||= Logging.logger[self]
        end
    end

    module Forwarder
        ::Logging::LEVELS.each do |name, _|
            define_method name do |*args, &block|
                logger.send(name, *args, &block)
            end
        end
    end
end

class Module
    def install_logging(forward: true)
        extend Installer
        if forward
            extend Forwarder
        end
    end
end

class Class
    def install_logging(forward: true, on_instance: false)
        super(forward: forward)
        if on_instance
            include Installer
            if forward
                include Forwarder
            end
        end
    end
end

module Snapsync
    install_logger(forward: true)
end

