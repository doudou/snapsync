require 'weakref'

module Snapsync
  class RemotePathname

    # @return [URI::SshGit::Generic]
    attr_reader :uri

    # @return [Net::SSH::Connection::Session]
    attr_reader :ssh

    # @return [Net::SFTP::Session]
    attr_reader :sftp

    # @return [Net::SFTP::Operations::FileFactory]
    attr_reader :sftp_f

    # @param [String] dir
    def initialize(dir)
      if dir.instance_of? RemotePathname
        @uri = dir.uri.dup
        @ssh = dir.ssh
        @sftp = dir.sftp
        @sftp_f = dir.sftp_f
      else
        @uri = URI::SshGit.parse(dir)

        raise RuntimeError.new('Host cannot be nil for remote pathname') if uri.host.nil?

        @ssh = Net::SSH.start(uri.host, uri.user, password: uri.password)

        @sftp = @ssh.sftp
        @sftp_f = @sftp.file

        # # FIXME: these probably don't work
        # @ssh_thr = Thread.new {
        #   ssh = WeakRef.new(@ssh)
        #   while ssh.weakref_alive?
        #     ssh.process 0.1
        #   end
        # }
        #
        # @sftp_thr = Thread.new {
        #   sftp = WeakRef.new(@sftp)
        #   sftp.loop do
        #     sftp.weakref_alive?
        #   end
        # }
      end
    end

    def initialize_dup(other)
      super
      @uri = @uri.dup
    end

    # Duplicates a new ssh session with same connection options
    # @return [Net::SSH::Connection::Session]
    def dup_ssh(&block)
      Net::SSH.start(uri.host, uri.user, password: uri.password, &block)
    end

    def directory?
      begin
        sftp_f.directory? uri.path
      rescue Net::SFTP::StatusException
        return false
      end
    end

    def mountpoint?
      ssh.exec!(Shellwords.join ['mountpoint','-q',uri.path]).exitstatus == 0
    end

    def basename
      Pathname.new(uri.path).basename
    end

    def dirname
      o = self.dup
      o.uri.path = Pathname.new(uri.path).dirname.to_s
      o
    end

    def parent
      o = self.dup
      if o.uri.path == '/'
        raise "Trying to get parent of root directory"
      end
      o.uri.path = Pathname.new(uri.path).parent.to_s
      o
    end

    def expand_path
      o = self.dup
      o.uri.path = ssh.exec!(Shellwords.join ['readlink', '-f', uri.path]).chomp
      o
    end

    def mkpath
      sftp.mkdir(uri.path)
    end

    def +(path)
      o = self.dup
      o.uri.path = (Pathname.new(uri.path) + path).to_s
      o
    end

    def read
      begin
        sftp_f.open(uri.path).read
      rescue Net::SFTP::StatusException => e
        raise Errno::ENOENT, e.message, e.backtrace
      end
    end

    def open(flags, &block)
      sftp_f.open uri.path, flags, block
    end

    def to_s
      uri.to_s
    end

    def inspect
      uri.to_s
    end
  end
end

# We monkey-patch this in to be able to tell machine-specific poth

class Pathname
  def path_part
    to_s
  end
end

module Snapsync
  class RemotePathname
    def path_part
      uri.path
    end
  end
end
