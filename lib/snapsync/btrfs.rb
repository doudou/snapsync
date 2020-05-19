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

        class UnexpectedBtrfsOutput < Error
        end

        def self.btrfs_prog
            ENV['BTRFS_PROG'] || 'btrfs'
        end

        # @api private
        #
        # A IO.popen-like API to btrfs subcommands
        def self.popen(*args, mode: 'r', raise_on_error: true, **options)
            err_r, err_w = IO.pipe

            block_error, block_result = nil
            IO.popen([btrfs_prog, *args, err: err_w, **options], mode) do |io|
                err_w.close

                begin
                    block_result = yield(io)
                rescue Error
                    raise
                rescue Exception => block_error
                end
            end

            if $?.success? && !block_error
                block_result
            elsif raise_on_error
                if block_error
                    raise Error.new, block_error.message
                else
                    raise Error.new, "btrfs failed"
                end
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
                io.read.encode('utf-8', undef: :replace, invalid: :replace)
            end
        end

        # Facade for finding the generation of a subvolume using 'btrfs show'
        #
        # @param [Pathname] path the subvolume path
        # @return [Integer] the subvolume's generation
        def self.generation_of(path)
            info = Btrfs.run('subvolume', 'show', path.to_s)
            if info =~ /Generation[^:]*:\s+(\d+)/
                Integer($1)
            else
                raise UnexpectedBtrfsOutput, "unexpected output for 'btrfs subvolume show', expected #{info} to contain a Generation: line"
            end
        end

        # Facade for checking readonly-flag on snapshot using 'btrfs subvolume show'
        #
        # @param [Pathname] path the subvolume path
        # @return [Boolean] if the snapshot is readonly
        def self.readonly(path)
            info = Btrfs.run('subvolume', 'show', path.to_s)
            if info =~ /Flags[^:]*:\s+(-|\w+)/
                "readonly" == $1.to_s
            else
                raise UnexpectedBtrfsOutput, "unexpected output for 'btrfs subvolume show', expected #{info} to contain a Flags: line"
            end
        end

        # Facade for 'btrfs subvolume find-new'
        #
        # It computes what changed between a reference generation of a
        # subvolume, and that subvolume's current state
        #
        # @param [String] subvolume_dir the subvolume target of find-new
        # @param [Integer] last_gen the reference generation
        #
        # @overload find_new(subvolume_dir, last_gen)
        #   @yieldparam [String] a line of the find-new output
        #
        # @overload find_new(subvolume_dir, last_gen)
        #   @return [#each] an enumeration of the lines of the find-new output
        def self.find_new(subvolume_dir, last_gen, &block)
            run('subvolume', 'find-new', subvolume_dir.to_s, last_gen.to_s).
                each_line(&block)
        end
    end
end
