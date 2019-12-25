require "optparse"

module Runners
  class CLI
    attr_reader :stdout
    attr_reader :stderr
    attr_reader :guid
    attr_reader :analyzer
    attr_reader :options

    def initialize(argv:, stdout:, stderr:)
      @stdout = stdout
      @stderr = stderr

      OptionParser.new do |opts|
        opts.on("--analyzer=ANALYZER") do |analyzer|
          @analyzer = analyzer
        end
      end.parse!(argv)
      @guid = _ = argv.shift

      raise "--analyzer is required" unless analyzer
      raise "The specified analyzer is not supported" unless processor_class
      raise "GUID is required" unless guid
      @options = Options.new(stdout, stderr)
    end

    def with_working_dir
      Dir.mktmpdir do |dir|
        yield Pathname(dir)
      end
    end

    def processor_class
      @processor_class ||= (Processor.subclasses.detect do |cls|
        "#{Processor.name}::#{analyzer.to_s.delete('_')}".casecmp?(cls.name)
      end or raise "Not found processor class with '#{analyzer}'")
    end

    def run
      io.flush! # Write or upload empty content to let the caller of Runners notice the beginning of the analysis.
      with_working_dir do |working_dir|
        writer = JSONSEQ::Writer.new(io: io)
        trace_writer = TraceWriter.new(writer: writer, sensitive_strings: sensitive_strings)
        started_at = Time.now
        trace_writer.header "Analysis started", recorded_at: started_at

        harness = Harness.new(guid: guid, processor_class: processor_class, options: options, working_dir: working_dir, trace_writer: trace_writer)

        result = harness.run
        warnings = harness.warnings
        ci_config = harness.ci_config
        json = {
          result: result.as_json,
          warnings: warnings,
          ci_config: ci_config,
          version: Runners::VERSION,
        }

        trace_writer.message "Writing result..." do
          writer << Schema::Result.envelope.coerce(json)
        end
        result.tap do
          finished_at = Time.now
          duration = finished_at - started_at
          trace_writer.header "Analysis finished in #{duration.round(3)}s", recorded_at: finished_at
        end
      end
    ensure
      io.flush! if defined?(:@io)
    end

    def io
      @io ||= options.io
    end

    def sensitive_strings
      @sensitive_strings ||= [].tap do |strings|
        source = options.source
        if source.is_a?(Options::GitSource)
          # @type var source: Options::GitSource
          strings << source.git_http_userinfo if source.git_http_userinfo
        end
      end
    end
  end
end
