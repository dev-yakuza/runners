module Runners
  class Processor::Ktlint < Processor
    include Java

    Schema = StrongJSON.new do
      def self.array_or?(type)
        array = array(type)
        enum?(type, array, detector: -> (value) {
          case value
          when Array
            array
          else
            type
          end
        })
      end

      def self.array_or(type)
        array = array(type)
        enum(type, array, detector: -> (value) {
          case value
          when Array
            array
          else
            type
          end
        })
      end

      let :reporter, enum(literal("json"), literal("plain"), literal("checkstyle"))

      let :gradle_config, object(
        task: string,
        reporter: reporter,
        output: string?
      )

      let :cli_config, object(
        patterns: array_or?(string),
        ruleset: array_or?(string),
        disabled_rules: array_or?(string),
        experimental: boolean?
      )

      let :maven_config, object(
        goal: string,
        reporter: reporter,
        output: string
      )

      let :cli, Schema::RunnerConfig.base.update_fields {|hash| hash[:cli] = cli_config}
      let :gradle, Schema::RunnerConfig.base.update_fields {|hash| hash[:gradle] = gradle_config}
      let :maven, Schema::RunnerConfig.base.update_fields {|hash| hash[:maven] = maven_config }
      let :base, Schema::RunnerConfig.base

      let :runner_config, enum(
        cli, gradle, maven, base,
        detector: -> (value) {
          case
          when value.key?(:cli)
            cli
          when value.key?(:gradle)
            gradle
          when value.key?(:maven)
            maven
          else
            base
          end
        }
      )
    end

    def self.ci_config_section_name
      'ktlint'
    end

    def ktlint_config
      @ktlint_config
    end

    def cli_config
      ktlint_config[:cli]
    end

    def gradle_config
      ktlint_config[:gradle]
    end

    def maven_config
      ktlint_config[:maven]
    end

    def run_cli
      args = ["--reporter=json"]

      cli_config[:ruleset].each do |ruleset|
        args.push("--ruleset", ruleset.to_s)
      end
      unless cli_config[:disabled_rules].empty?
        args.push("--disabled_rules", cli_config[:disabled_rules].join(","))
      end
      if cli_config[:experimental]
        args.push("--experimental")
      end

      stdout, = capture3(analyzer_bin, *args, *cli_config[:patterns])

      construct_json_result(stdout)
    end

    def run_gradle
      stdout, = capture3("./gradlew", "--quiet", gradle_config[:task])

      output_file = gradle_config[:output]
      output = if output_file
                 trace_writer.message "Reading output from #{output_file}..."
                 (current_dir + output_file).read.tap do |out|
                   trace_writer.message out
                 end
               else
                 stdout
               end

      construct_result(gradle_config[:reporter], output)
    end

    def run_maven
      mvn_options = %w[--quiet --batch-mode -Dmaven.test.skip=true -Dmaven.main.skip=true]

      # NOTE: `mvn` fails when issues are found, so we should not check the exit status.
      capture3("mvn", maven_config[:goal], *mvn_options)

      output_file = maven_config[:output]
      output_file_path = current_dir / output_file
      if output_file_path.exist?
        trace_writer.message "Reading output from #{output_file}..."
        output = output_file_path.read
        trace_writer.message output
      else
        msg = "#{output_file} does not exist because an unexpected error occurred!"
        trace_writer.error msg
        raise msg
      end

      construct_result(maven_config[:reporter], output)
    end

    def analyzer_version
      unknown_version = "0.0.0"

      @analyzer_version ||=
        case
        when gradle_config
          extract_ktlint_version_for_gradle || unknown_version
        when maven_config
          extract_ktlint_version_for_maven || unknown_version
        else
          extract_version! analyzer_bin
        end
    end

    def extract_ktlint_version_for_gradle
      stdout, = capture3!("./gradlew", "--quiet", "dependencies")
      stdout.each_line do |line|
        line.match(/com\.pinterest:ktlint:([\d\.]+)/) do |match|
          return match.captures.first
        end
      end
    end

    def extract_ktlint_version_for_maven
      pom_file = current_dir / "pom.xml"
      return unless pom_file.exist?

      groupId = "com.pinterest"
      artifactId = "ktlint"
      pom = REXML::Document.new(pom_file.read)
      pom.root.each_element("//dependency/groupId[text()='#{groupId}']") do |element|
        dependency = element.parent
        if dependency.elements["artifactId"].text == artifactId
          return dependency.elements["version"].text
        end
      end
    end

    def analyzer_name
      'ktlint'
    end

    def analyze(changes)
      show_java_runtime_versions

      ensure_runner_config_schema(Schema.runner_config) do |config|
        delete_unchanged_files changes, only: [".kt", ".kts"]

        check_runner_config(config) do |checked_config|
          @ktlint_config = checked_config

          issues = case
                   when gradle_config
                     run_gradle
                   when maven_config
                     run_maven
                   else
                     run_cli
                   end

          Results::Success.new(guid: guid, analyzer: analyzer).tap do |result|
            issues.each do |issue|
              result.add_issue issue
            end
          end
        end
      end
    end

    def construct_result(reporter, output)
      case reporter
      when "json"
        construct_json_result(output)
      when "checkstyle"
        construct_checkstyle_result(output)
      when "plain"
        construct_plain_result(output)
      end
    end

    def construct_issue(file:, line:, message:, rule: "")
      Issues::Text.new(
        path: relative_path(working_dir.realpath / file, from: working_dir.realpath),
        location: Location.new(start_line: line),
        id: rule.empty? ? Digest::SHA1.hexdigest(message)[0, 8] : rule,
        message: message,
        links: [],
      )
    end

    def construct_json_result(output)
      json = JSON.parse(output, symbolize_names: true)

      json.flat_map do |hash|
        hash[:errors].map do |error|
          construct_issue(
            file: hash[:file],
            line: error[:line],
            message: error[:message],
            rule: error[:rule],
          )
        end
      end
    end

    def construct_checkstyle_result(output)
      document = REXML::Document.new(output)

      unless document.root
        msg = "Invalid XML output!"
        trace_writer.error msg
        raise msg
      end

      issues = []

      document.root.each_element("file") do |file|
        file.each_element do |error|
          case error.name
          when "error"
            issues << construct_issue(
              file: file[:name],
              line: error[:line],
              message: error[:message],
              rule: error[:source],
            )
          when "exception"
            add_warning error.text.strip, file: file[:name]
          end
        end
      end

      issues
    end

    def construct_plain_result(output)
      output.lines(chomp: true).map do |line|
        match = line.match(/\A([^:]+):(\d+):(\d+):(.+)\Z/)
        if match
          path, line, _column, message = match.captures
          construct_issue(
            file: path,
            line: line,
            message: message.strip,
          )
        else
          raise "Unexpected line: #{line.inspect}"
        end
      end
    end

    def check_runner_config(config)
      case
      when config[:gradle]
        yield(
          {
            gradle: {
              task: config[:gradle][:task],
              reporter: config[:gradle][:reporter],
              output: config[:gradle][:output]
            }
          }
        )
      when config[:maven]
        yield(
          {
            maven: {
              goal: config[:maven][:goal],
              reporter: config[:maven][:reporter],
              output: config[:maven][:output]
            }
          }
        )
      when config[:cli]
        yield(
          {
            cli: {
              patterns: Array(config[:cli][:patterns]),
              ruleset: Array(config[:cli][:ruleset]),
              disabled_rules: Array(config[:cli][:disabled_rules]),
              experimental: config[:cli][:experimental] || false
            }
          }
        )
      else
        yield(
          {
            cli: {
              patterns: [],
              ruleset: [],
              disabled_rules: [],
              experimental: false
            }
          }
        )
      end
    end
  end
end
