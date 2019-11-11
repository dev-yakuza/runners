module Runners
  class Processor::PmdJava < Processor
    include Java

    Schema = StrongJSON.new do
      let :runner_config, Schema::RunnerConfig.base.update_fields { |fields|
        fields.merge!({
                        dir: string?,
                        rulesets: enum?(string, array(string)),
                        encoding: string?,
                        min_priority: numeric?
                      })
      }
    end

    DEFAULT_RULESETS = %w[
      category/java/bestpractices.xml
      category/java/errorprone.xml
      category/java/multithreading.xml
      category/java/performance.xml
      category/java/security.xml
    ].freeze

    def self.ci_config_section_name
      'pmd_java'
    end

    def pmd(dir:, rulesets:, encoding:, min_priority:)
      args = []
      args.unshift("-dir", dir)
      args.unshift("-rulesets", rulesets.join(","))
      args.unshift("-minimumpriority", min_priority.to_s) if min_priority
      args.unshift("-encoding", encoding) if encoding

      capture3(analyzer_bin, "-language", "java", "-format", "xml", *args)
    end

    def analyzer_version
      @analyzer_version ||= capture3!("show_pmd_version").yield_self { |stdout,| stdout.strip }
    end

    def analyzer_name
      'pmd_java'
    end

    def analyzer_bin
      "pmd"
    end

    def analyze(changes)
      show_java_runtime_versions

      ensure_runner_config_schema(Schema.runner_config) do |config|
        trace_writer.message("PMD version: #{analyzer_version}")
        delete_unchanged_files changes, only: [".java"]

        check_runner_config(config) do |dir, rulesets, encoding, min_priority|
          run_analyzer(dir, rulesets, encoding, min_priority)
        end
      end
    end

    def run_analyzer(dir, rulesets, encoding, min_priority)
      stdout, stderr, status = pmd(dir: dir, rulesets: rulesets, encoding: encoding, min_priority: min_priority)

      if status.success? || status.exitstatus == 4
        Results::Success.new(guid: guid, analyzer: analyzer).tap do |result|
          construct_result(result, stdout, stderr)
        end
      else
        Results::Failure.new(guid: guid, analyzer: analyzer, message: "Unexpected error occurred. Please see the analysis log.")
      end
    end

    def construct_result(result, stdout, stderr)
      # https://github.com/pmd/pmd.github.io/blob/8b0c31ff8e18215ed213b7df400af27b9137ee67/report_2_0_0.xsd

      REXML::Document.new(stdout).root.each_element do |element|
        case element.name
        when "file"
          path = relative_path(element[:name])

          element.each_element("violation") do |violation|
            links = array(violation[:externalInfoUrl])

            message = violation.text.strip
            id = violation[:ruleset] + "-" + violation[:rule] + "-" + Digest::SHA1.hexdigest(message)

            result.add_issue Issue.new(
              path: path,
              location: Location.new(
                start_line: violation[:beginline],
                start_column: violation[:begincolumn],
                end_line: violation[:endline],
                end_column: violation[:endcolumn],
              ),
              id: id,
              message: message,
              links: links,
            )
          end

        when "error"
          add_warning element[:msg], file: relative_path(element[:filename]).to_s

        when "configerror"
          add_warning "#{element[:rule]}: #{element[:msg]}"

        end
      end

      stderr.each_line do |line|
        case line
        when /WARNING: This analysis could be faster, please consider using Incremental Analysis/
          # We cannot support "incremental analysis" for now. So, ignore it.
        when /WARNING: (.+)$/
          add_warning $1
        end
      end
    end

    def check_runner_config(config)
      dir = check_directory(config)
      trace_writer.message("Checking directory: #{dir}")

      rulesets = rulesets(config)
      trace_writer.message("Rulesets: #{rulesets.join(", ")}")

      encoding = encoding(config)
      trace_writer.message("Source encoding: #{encoding}") if encoding

      min_priority = min_priority(config)
      trace_writer.message("Min priority: #{min_priority}") if min_priority

      yield dir, rulesets, encoding, min_priority
    end

    def rulesets(config)
      array(config[:rulesets] || DEFAULT_RULESETS)
    end

    def check_directory(config)
      config[:dir] || "."
    end

    def encoding(config)
      config[:encoding]
    end

    def min_priority(config)
      config[:min_priority]
    end

    def array(value)
      case value
      when Hash
        [value]
      else
        Array(value)
      end
    end
  end
end
