require_relative 'test_helper'

class OptionsTest < Minitest::Test
  include TestHelper

  def test_options_archive_source_full
    source_params = {
      head: 'http://example.com/head',
      head_key: 'head_key',
      base: 'http://example.com/base',
      base_key: 'base_key',
    }
    with_runners_options_env(source: source_params) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of Runners::Options::ArchiveSource, options.source
      assert_equal source_params, options.source.to_h
    end
  end

  def test_options_archive_source_head_only
    source_params = {
      head: 'http://example.com/head',
      head_key: 'head_key',
    }
    with_runners_options_env(source: source_params) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of Runners::Options::ArchiveSource, options.source
      assert_equal source_params.merge(base: nil, base_key: nil), options.source.to_h
    end
  end

  def test_options_archive_source_head_only_without_key
    source_params = {
      head: 'http://example.com/head',
    }
    with_runners_options_env(source: source_params) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of Runners::Options::ArchiveSource, options.source
      assert_equal source_params.merge(head_key: nil, base: nil, base_key: nil), options.source.to_h
    end
  end

  def test_options_archive_source_full_source_without_base_key
    source_params = {
      head: 'http://example.com/head',
      head_key: 'head_key',
      base: 'http://example.com/base',
    }
    with_runners_options_env(source: source_params) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of Runners::Options::ArchiveSource, options.source
      assert_equal source_params.merge(base_key: nil), options.source.to_h
    end
  end

  def test_options_archive_source_full_source_without_head_key
    source_params = {
      head: 'http://example.com/head',
      base: 'http://example.com/base',
      base_key: 'base_key',
    }
    with_runners_options_env(source: source_params) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of Runners::Options::ArchiveSource, options.source
      assert_equal source_params.merge(head_key: nil), options.source.to_h
    end
  end

  def test_options_git_source
    source_params = {
      head: 'head_commit',
      base: 'base_commit',
      git_http_url: 'https://github.com',
      owner: 'foo',
      repo: 'bar',
      git_http_userinfo: 'user:secret',
      pull_number: 1234,
    }
    with_runners_options_env(source: source_params) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of Runners::Options::GitSource, options.source
      assert_equal source_params, options.source.to_h
    end
  end

  def test_options_git_source_without_base
    source_params = {
      head: 'head_commit',
      git_http_url: 'https://github.com',
      owner: 'foo',
      repo: 'bar',
      git_http_userinfo: 'user:secret',
      pull_number: 1234,
    }
    with_runners_options_env(source: source_params) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of Runners::Options::GitSource, options.source
      assert_equal source_params.merge(base: nil), options.source.to_h
    end
  end

  def test_options_git_source_without_userinfo
    source_params = {
      head: 'head_commit',
      base: 'base',
      git_http_url: 'https://github.com',
      owner: 'foo',
      repo: 'bar',
      pull_number: 1234,
    }
    with_runners_options_env(source: source_params) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of Runners::Options::GitSource, options.source
      assert_equal source_params.merge(git_http_userinfo: nil), options.source.to_h
    end
  end

  def test_options_git_source_without_pull_number
    source_params = {
      head: 'head_commit',
      base: 'base',
      git_http_url: 'https://github.com',
      owner: 'foo',
      repo: 'bar',
      git_http_userinfo: 'user:secret',
    }
    with_runners_options_env(source: source_params) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of Runners::Options::GitSource, options.source
      assert_equal source_params.merge(pull_number: nil), options.source.to_h
    end
  end

  def test_options_with_ssh_key
    with_runners_options_env(source: { head: 'http://example.com/head' },
                             ssh_key: 'ssh') do
      options = Runners::Options.new(stdout, stderr)
      assert_equal 'ssh', options.ssh_key
    end
  end

  def test_options_without_ssh_key
    with_runners_options_env(source: { head: 'http://example.com/head' }) do
      options = Runners::Options.new(stdout, stderr)
      assert_nil options.ssh_key
    end
  end

  def test_options_with_outputs
    with_runners_options_env(source: { head: 'http://example.com/head' },
                             outputs: %w[stdout stderr]) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of(Runners::IO, options.io)
      assert_equal [stdout, stderr], options.io.ios
    end
  end

  def test_options_with_outputs_s3_url
    with_runners_options_env(source: { head: 'http://example.com/head' },
                             outputs: %w[stdout s3://bucket/abc]) do
      s3_mock = Object.new
      stub(s3_mock).write
      stub(s3_mock).flush
      stub(s3_mock).flush!
      mock(Runners::IO::AwsS3).new("s3://bucket/abc") { s3_mock }
      mock.proxy(Runners::IO).new(stdout, s3_mock)

      options = Runners::Options.new(stdout, stderr)
      assert_instance_of(Runners::IO, options.io)
      assert_equal [stdout, s3_mock], options.io.ios
    end
  end

  def test_options_without_outputs
    with_runners_options_env(source: { head: 'http://example.com/head' }) do
      options = Runners::Options.new(stdout, stderr)
      assert_instance_of(Runners::IO, options.io)
      assert_equal [stdout], options.io.ios
    end
  end

  def stdout
    @stdout ||= StringIO.new
  end

  def stderr
    @stderr ||= StringIO.new
  end
end
