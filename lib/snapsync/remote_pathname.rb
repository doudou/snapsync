require 'weakref'

class Pathname
  class NonZeroExitCode < RuntimeError
  end

  def path_part
    to_s
  end

  def touch
    FileUtils.touch(to_s)
  end

  def findmnt
    # An optimization to quickly get the mountpoint.
    # 3 levels are needed to get from `.snapshots/<id>/snapshot` to a cached entry.
    # Will probably be fine.
    cached = Snapsync._mountpointCache.fetch(self.to_s, nil)
    cached = Snapsync._mountpointCache.fetch(self.parent.to_s, nil) unless cached
    cached = Snapsync._mountpointCache.fetch(self.parent.parent.to_s, nil) unless cached
    return cached.dup if cached

    Snapsync.debug "Pathname ('#{self}').findmnt"

    proc = IO.popen(Shellwords.join ['findmnt','-n','-o','TARGET','-T', self.to_s])
    path = proc.read.strip
    proc.close
    if not $?.success?
      raise NonZeroExitCode, "findmnt failed for #{self}"
    end

    raise "findmnt failed" unless path
    p = Pathname.new path
    # Update cache
    p2 = self.dup
    while p != p2
      Snapsync._mountpointCache[p2.to_s] = p
      p2 = p2.parent
    end
    p
  end
end

module Snapsync
  class << self
    # @return [Hash]
    attr_accessor :_mountpointCache
  end
  self._mountpointCache = {}

  class AgnosticPath
    def exist?
      raise NotImplementedError
    end
    def file?
      raise NotImplementedError
    end
    def directory?
      raise NotImplementedError
    end
    def mountpoint?
      raise NotImplementedError
    end
    def basename
      raise NotImplementedError
    end
    def dirname
      raise NotImplementedError
    end
    def parent
      raise NotImplementedError
    end
    def each_child
      raise NotImplementedError
    end
    def expand_path
      raise NotImplementedError
    end
    def cleanpath
      raise NotImplementedError
    end
    def mkdir
      raise NotImplementedError
    end
    def mkpath
      raise NotImplementedError
    end
    def rmtree
      raise NotImplementedError
    end
    def unlink
      raise NotImplementedError
    end
    # @return [AgnosticPath]
    def +(path)
      raise NotImplementedError
    end
    def read
      raise NotImplementedError
    end
    def open(flags, &block)
      raise NotImplementedError
    end
    def touch
      raise NotImplementedError
    end

    def findmnt
      raise NotImplementedError
    end

    # @return [String]
    def path_part
      raise NotImplementedError
    end
  end

  # Ideally this would also inherit from AgnosticPath...
  class LocalPathname < Pathname
  end

  class RemotePathname < AgnosticPath

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

        Snapsync.debug "Opening new ssh session: "+uri.to_s
        @ssh = Net::SSH.start(uri.host, uri.user, password: uri.password, non_interactive: true)

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
    # @yieldparam ssh [Net::SSH::Connection::Session]
    def dup_ssh(&block)
      Snapsync.debug "Opening new ssh session: "+uri.to_s
      Net::SSH.start(uri.host, uri.user, password: uri.password, non_interactive: true, &block)
    end

    def exist?
      begin
        sftp_f.open(uri.path).close
        return true
      rescue Net::SFTP::StatusException
        return directory?
      end
    end

    def file?
      begin
        sftp_f.open(uri.path).close
        return true
      rescue Net::SFTP::StatusException
        return false
      end
    end

    def directory?
      begin
        sftp_f.directory? uri.path
      rescue Net::SFTP::StatusException
        return false
      end
    end

    def findmnt
      cached = Snapsync._mountpointCache.fetch(self.to_s, nil)
      cached = Snapsync._mountpointCache.fetch(self.parent.to_s, nil) unless cached
      return cached if cached

      Snapsync.debug "RemotePathname ('#{uri}').findmnt"

      path = ssh.exec!(Shellwords.join ['findmnt','-n','-o','TARGET','-T',uri.path]).strip
      p = self.dup
      p.uri.path = path

      # Update cache
      p2 = self.dup
      while p.uri.path != p2.uri.path
        Snapsync._mountpointCache[p2.to_s] = p
        p2 = p2.parent
      end

      p
    end

    def mountpoint?
      Snapsync.debug "RemotePathname ('#{uri}').mountpoint?"
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

    def each_child(with_directory=true, &block)
      raise 'Only supports default value for with_directory' if not with_directory

      sftp.dir.foreach(uri.path) do |entry|
        next if entry.name == '.' or entry.name == '..'

        o = self.dup
        o.uri.path = (Pathname.new(o.uri.path) + entry.name).to_s
        yield o
      end
    end

    def expand_path
      o = self.dup
      o.uri.path = ssh.exec!(Shellwords.join ['readlink', '-f', uri.path]).chomp
      o
    end

    def cleanpath
      o = self.dup
      o.uri.path = Pathname.new(uri.path).cleanpath.to_s
      o
    end

    def mkdir
      sftp.mkdir!(uri.path)
    end

    def mkpath
      sftp.mkdir!(uri.path)
    end

    def rmtree
      raise 'Failed' unless ssh.exec!(Shellwords.join ['rm','-r', uri.path]).exitstatus == 0
    end

    def unlink
      raise 'Failed' unless ssh.exec!(Shellwords.join ['rm', uri.path]).exitstatus == 0
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
      sftp_f.open uri.path, flags, &block
    end

    def touch
      raise 'Failed' unless ssh.exec!(Shellwords.join ['touch', uri.path]).exitstatus == 0
    end

    def path_part
      uri.path
    end

    def to_s
      uri.to_s
    end

    def inspect
      uri.to_s
    end
  end
end
