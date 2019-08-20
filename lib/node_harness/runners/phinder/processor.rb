module NodeHarness
  module Runners
    module Phinder
      class Processor < NodeHarness::Processor
        Schema = StrongJSON.new do
          let :runner_config, NodeHarness::Schema::RunnerConfig.base.update_fields { |fields|
            fields.merge!({
                            rule: string?,
                            php: string?,
                          })
          }

          let :issue_object, object(
            id: string,
            message: string,
            justifications: array(string),
          )
        end

        def self.ci_config_section_name
          "phinder"
        end

        def analyzer
          @analyzer ||= NodeHarness::Analyzer.new(name: "Phinder", version: @analyzer_version)
        end

        def test_phinder_config(config)
          args = []
          args.push("--config", config[:rule]) if config[:rule]

          _, stderr, status = capture3("phinder", "test", *args)

          # 0: Success (No configuration error & no test failure)
          # 1: Configuration error
          # 2: Test failure
          case status.exitstatus
          when 0
            # noop
          when 1
            # Skip other configuration errors.
            # These errors should be reported when running `phinder find`.
          when 2
            add_warning(<<~MESSAGE.chomp, file: config[:rule] || "phinder.yml")
              Phinder configuration validation failed.
              Check the following output by `phinder test` command.

              #{stderr}
            MESSAGE
          else
            raise <<~MESSAGE
              Phinder test was failed with status #{status.exitstatus} since an unexpected error occurred.
              STDERR:
              #{stderr}
            MESSAGE
          end
        end

        def run_phinder(config)
          args = []
          args.push("--config", config[:rule]) if config[:rule]
          args << config[:php] if config[:php]

          stdout, stderr, status = capture3("phinder", "find", "-f", "json", *args)

          # 0: Success (No error & no violations are found)
          # 1: Error (Error & no violations are found)
          # 2: Violation (No error & violations are found)
          # 3: Error & Violation
          case status.exitstatus
          when 0
            NodeHarness::Results::Success.new(guid: guid, analyzer: analyzer)
          when 2
            json = JSON.parse(stdout, symbolize_names: true)

            NodeHarness::Results::Success.new(guid: guid, analyzer: analyzer).tap do |result|
              json[:result].each do |issue|
                result.add_issue NodeHarness::Issues::Structured.new(
                  id: issue[:rule][:id],
                  path: relative_path(issue[:path]),
                  location: NodeHarness::Location.new(
                    start_line: issue[:location][:start][0],
                    start_column: issue[:location][:start][1],
                    end_line: issue[:location][:end][0],
                    end_column: issue[:location][:end][1],
                  ),
                  object: {
                    id: issue[:rule][:id],
                    message: issue[:rule][:message],
                    justifications: Array(issue[:justifications]),
                  },
                  schema: Schema.issue_object,
                )
              end
            end
          when 1, 3
            json = JSON.parse(stdout, symbolize_names: true)
            # TODO: Handling violations?
            NodeHarness::Results::Failure.new(guid: guid, message: <<~MESSAGE, analyzer: analyzer)
              #{json[:errors].size} #{"error".pluralize(json[:errors].size)} occurred:

              #{json[:errors].map { |error| "#{error[:type]}: #{error[:message]}" }.join("\n")}
            MESSAGE
          else
            raise <<~MESSAGE
              Phinder analysis was failed with status #{status.exitstatus} since an unexpected error occurred.
              STDERR:
              #{stderr}
            MESSAGE
          end
        end

        def analyze(changes)
          delete_unchanged_files(changes, except: ["*.yml", "*.yaml"])

          # Print analyzer version to trace
          stdout, _ = capture3!("phinder", "--version")
          @analyzer_version = stdout.match(/([0-9\.]+)/).captures.first

          ensure_runner_config_schema(Schema.runner_config) do |config|
            ensure_phinder_config_files relative_path("phinder.yml") do
              test_phinder_config config
              run_phinder config
            end
          end
        end

        # TODO: Implement methods as a NodeHarness utility
        def ensure_phinder_config_files(*paths)
          trace_writer.message "Checking if required file exists: #{paths.join(', ')}"

          file = paths.find { |path| (working_dir + path).file? }
          if file
            trace_writer.message "Found #{file}"
            yield file
          else
            trace_writer.error "No file found..."
            add_warning(<<~MESSAGE, file: "phinder.yml")
              File not found: `phinder.yml`. This file is necessary for analysis.
              See also: https://help.sider.review/tools/php/phinder
            MESSAGE
            NodeHarness::Results::Success.new(guid: guid, analyzer: analyzer)
          end
        end
      end
    end
  end
end
