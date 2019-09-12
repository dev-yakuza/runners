module NodeHarness
  class Processor::Flake8 < Processor
    FLAKE8_OUTPUT_FORMAT = '%(code)s:::%(path)s:::%(row)d:::%(col)d:::%(text)s'.freeze

    Schema = StrongJSON.new do
      let :runner_config, Schema::RunnerConfig.base.update_fields { |fields|
        fields.merge!({
                        version: numeric?,
                        plugins: enum?(string, array(string))
                      })
      }
    end

    def self.ci_config_section_name
      'flake8'
    end

    def setup
      prepare_config
      yield
    end

    def analyze(changes)
      ensure_runner_config_schema(Schema.runner_config) do |config|
        capture3!('pyenv', 'global', detected_python_version(config))
        prepare_plugins(config)
        run_analyzer
      end
    end

    private

    def analyzer
      Analyzer.new(name: 'Flake8', version: analyzer_version)
    end

    def prepare_config
      default_config = (Pathname(Dir.home) / '.config/flake8').realpath
      return default_config.delete if (current_dir / '.flake8').exist?
      configs = %w[setup.cfg tox.ini].select do |v|
        path = (current_dir + v)
        path.exist? && path.read.match(/^\[flake8\]$/m)
      end
      return default_config.delete unless configs.empty?
    end

    def prepare_plugins(config)
      if config[:plugins]
        plugins = Array(config[:plugins]).flatten
        capture3!('pip', 'install', *plugins)
      end
    end

    def detected_python_version(config)
      [
        specified_python_version(config),
        specified_python_version_via_pyenv,
        python3_version
      ].compact.first
    end

    def specified_python_version(config)
      case config[:version]&.to_i
      when 2
        python2_version
      when 3
        python3_version
      end
    end

    def specified_python_version_via_pyenv
      python_version = Pathname(current_dir + '.python-version')
      if python_version.exist?
        version = if python_version.read.start_with? '2'
                    python2_version
                  else
                    python3_version
                  end
        # Delete .python-version not to run Python that is not installed.
        python_version.delete
        return version
      end
    end

    def ignored_config_path
      (Pathname(Dir.home) / '.config/ignored-config.ini').realpath
    end

    def python2_version
      @python2_version ||= capture3!('pyenv', 'versions', '--bare').first.match(/^2[0-9\.]+$/m).to_s
    end

    def python3_version
      @python3_version ||= capture3!('pyenv', 'versions', '--bare').first.match(/^3[0-9\.]+$/m).to_s
    end

    def analyzer_version
      @analyzer_version ||= extract_version! 'flake8'
    end

    def parse_result(output)
      # Output example:
      #
      # E999:::app1/views.py:::6:::12:::IndentationError: unexpected indent
      #
      # `:::` is a separater
      #
      output.split("\n").map do |value|
        id, path, line, _, message = value.split(':::')
        loc = Location.new(
          start_line: line.to_i,
          start_column: nil,
          end_line: nil,
          end_column: nil
        )
        Issues::Text.new(
          path: relative_path(path),
          location: loc,
          id: id,
          message: "[#{id}] #{message}",
          links: []
        )
      end.compact
    end

    def run_analyzer
      Results::Success.new(guid: guid, analyzer: analyzer).tap do |result|
        output = Dir.mktmpdir do |tmpdir|
          output_path = Pathname(tmpdir) + 'output.txt'
          capture3!(
            'flake8',
            '--exit-zero',
            "--output-file=#{output_path}",
            "--format=#{FLAKE8_OUTPUT_FORMAT}",
            "--append-config=#{ignored_config_path}",
            './'
          )
          output_path.read
        end
        break result if output.empty?
        trace_writer.message output
        parse_result(output).each { |v| result.add_issue(v) }
      end
    end
  end
end
