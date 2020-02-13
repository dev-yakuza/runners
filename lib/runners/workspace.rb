module Runners
  class Workspace
    class DownloadError < SystemError; end

    def self.prepare(options:, working_dir:, trace_writer:)
      source = options.source
      case source
      when Options::ArchiveSource
        case
        when source.http?
          Workspace::HTTP.new(options: options, working_dir: working_dir, trace_writer: trace_writer)
        when source.file?
          Workspace::File.new(options: options, working_dir: working_dir, trace_writer: trace_writer)
        else
          raise ArgumentError, "The specified options #{options.inspect} is not supported"
        end
      when Options::GitSource
        Workspace::Git.new(options: options, working_dir: working_dir, trace_writer: trace_writer)
      end
    end

    attr_reader :options, :working_dir, :trace_writer

    # @param options [Options]
    # @param working_dir [Pathname]
    # @param trace_writer [Runners::TraceWriter]
    def initialize(options:, working_dir:, trace_writer:)
      @options = options
      @working_dir = working_dir
      @trace_writer = trace_writer
    end

    # @yieldparam git_ssh_path [Pathname, nil]
    # @yieldparam changes [Runners::Changes]
    def open
      prepare_ssh do |git_ssh_path|
        Dir.mktmpdir do |base_dir|
          base_path = Pathname(base_dir)
          Dir.mktmpdir do |head_dir|
            head_path = Pathname(head_dir)

            trace_writer.header "Setting up source code"
            if options.source.base
              trace_writer.message "Preparing base commit tree..."
              prepare_base_source(base_path)
            end
            trace_writer.message "Preparing head commit tree..."
            prepare_head_source(head_path)

            trace_writer.message "Copying head to working dir..." do
              FileUtils.copy_entry(head_path, working_dir)
            end

            changes = trace_writer.message "Calculating changes between head and base..." do
              Changes.calculate(base_dir: base_path, head_dir: head_path, working_dir: working_dir, patches: patches)
            end

            yield git_ssh_path, changes
          end
        end
      end
    ensure
      FileUtils.remove_entry root_tmp_dir
    end

    def root_tmp_dir
      @root_tmp_dir ||= Pathname(Dir.mktmpdir)
    end

    def range_git_blame_info(path_string, start_line, end_line)
      []
    end

    private

    def archive_source
      @archive_source ||=
        begin
          source = options.source
          if source.instance_of?(Runners::Options::ArchiveSource)
            source
          else
            raise "#{source.inspect} is not ArchiveSource"
          end
        end
    end

    def git_source
      @git_source ||=
        begin
          source = options.source
          if source.instance_of?(Runners::Options::GitSource)
            source
          else
            raise "#{source.inspect} is not GitSource"
          end
        end
    end

    def prepare_ssh
      ssh_key = options.ssh_key
      if ssh_key
        Dir.mktmpdir do |dir|
          trace_writer.message "Preparing SSH config..."

          config_path = Pathname(dir) / 'config'
          key_path = Pathname(dir) / 'key'
          script_path = Pathname(dir) / 'run.sh'
          known_hosts_path = Pathname(dir) / 'known_hosts'

          config_path.write(<<~SSH_CONFIG, perm: 0600)
            Host *
              CheckHostIP no
              ConnectTimeout 30
              UserKnownHostsFile #{known_hosts_path}
              StrictHostKeyChecking no
              IdentitiesOnly yes
              IdentityFile #{key_path}
          SSH_CONFIG
          key_path.write(ssh_key, perm: 0600)
          known_hosts_path.write('', perm: 0600)
          script_path.write(<<~GIT_SSH, perm: 0700)
            #!/bin/sh
            ssh -F #{config_path} "$@"
          GIT_SSH
          yield script_path
        end
      else
        trace_writer.message "Nothing to do"
        yield nil
      end
    end

    def prepare_base_source(dest)
      raise NotImplementedError
    end

    def prepare_head_source(dest)
      raise NotImplementedError
    end

    def decrypt(archive, key)
      Dir.mktmpdir do |tmpdir|
        tmppath = Pathname(tmpdir)

        if key
          decrypted_path = tmppath.join(SecureRandom.uuid)

          trace_writer.message "Encryption key is given; decrypting..." do
            decrypt_by_openssl(archive, key, decrypted_path)
          end

          yield decrypted_path
        else
          yield archive
        end
      end
    end

    def decrypt_by_openssl(archive, password, out_path)
      dec = OpenSSL::Cipher.new("AES-256-CBC")
      dec.decrypt
      archive.open do |f|
        salt = f.read(dec.iv_len).force_encoding('ASCII-8BIT')[8, dec.iv_len]
        dec.pkcs5_keyivgen(password, salt, 1, 'md5')

        out_path.open('w') do |out|
          while data = f.read(100_000_000)&.force_encoding('ASCII-8BIT')
            out.write(dec.update(data))
          end
          out.write(dec.final)
        end
      end
    end

    def extract(archive, dir)
      trace_writer.message "Extracting archive to directory..." do
        out, status = Open3.capture2e("tar", "xf", archive.to_s, chdir: dir)
        raise "Extracting archive failed - #{out}" unless status.success?
      end
    end

    def patches
      nil
    end
  end
end
