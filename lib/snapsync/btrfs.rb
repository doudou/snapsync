module Snapsync
    module Btrfs
        class Error < RuntimeError
            attr_reader :error_lines
            def initialize(error_lines = Array.new)
                @error_lines = error_lines
            end

            def pretty_print(pp)
                pp.text message
                pp.nest(2) do
                    error_lines.each do |l|
                        pp.breakable
                        pp.text l.chomp
                    end
                end
            end
        end

        def self.popen(*args, mode: 'r', raise_on_error: true, **options)
            err_r, err_w = IO.pipe
            result = IO.popen(['btrfs', *args, err: err_w, **options], mode) do |io|
                err_w.close
                yield(io)
            end

            if $?.success?
                result
            elsif raise_on_error
                raise Error.new, "btrfs failed"
            end

        rescue Error => e
            prefix = args.join(" ")
            lines = err_r.readlines.map do |line|
                "#{prefix}: #{line.chomp}"
            end
            raise Error.new(e.error_lines + lines), e.message, e.backtrace

        ensure err_r.close
        end

        def self.run(*args, **options)
            popen(*args, **options) do |io|
                io.read
            end
        end
    end
end
