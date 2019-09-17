module Runners
  module Results
    class Base
      # @dynamic guid, timestamp
      attr_reader :guid
      attr_reader :timestamp

      def initialize(guid:)
        @guid = guid
        @timestamp = Time.now
      end

      def as_json
        {
          guid: guid,
          timestamp: timestamp.utc.iso8601
        }
      end

      def valid?
        guid && timestamp
      end
    end

    # Result to indicate that processing finished successfully
    # Client programs may return this result.
    class Success < Base
      class InvalidIssue < StandardError
        # @dynamic issue
        attr_reader :issue

        def initialize(issue:)
          @issue = issue
        end

        def inspect
          "#<#{self.class.name}: issue=#{issue.inspect}>"
        end
      end

      # @dynamic issues, analyzer
      attr_reader :issues
      attr_reader :analyzer

      def initialize(guid:, analyzer:)
        super(guid: guid)
        @issues = []
        @analyzer = analyzer
      end

      def as_json
        super.tap do |json|
          json[:type] = 'success'
          json[:issues] = issues.map(&:as_json).sort_by! {|issue| [issue[:id], issue[:path], issue.dig(:location, :start_line)]}
          json[:analyzer] = analyzer.as_json
        end
      end

      def valid?
        super && issues.all?(&:valid?) && analyzer&.valid?
      end

      def add_issue(issue)
        raise InvalidIssue.new(issue: issue) unless issue.valid?
        issues << issue
      end

      def filter_issue
        if block_given?
          result = self.class.new(guid: guid, analyzer: analyzer)
          issues.each do |issue|
            result.add_issue(issue) if yield(issue)
          end
          result
        else
          enum_for :filter_issues
        end
      end
    end

    # Result to indicate that processing failed by some error.
    # Client programs may return this result.
    class Failure < Base
      # @dynamic message, analyzer
      attr_reader :message
      attr_reader :analyzer

      def initialize(guid:, message:, analyzer: nil)
        super(guid: guid)
        @message = message
        @analyzer = analyzer
      end

      def as_json
        super.tap do |json|
          json[:type] = 'failure'
          json[:message] = message
          json[:analyzer] = analyzer&.as_json
        end
      end

      def valid?
        super && message && ((a = analyzer) ? a.valid? : true)
      end
    end

    # Result to indicate failure because of absent of files.
    # At least one of given files must be present for analysis.
    # Client programs may return this result.
    class MissingFilesFailure < Base
      # @dynamic files
      attr_reader :files

      def initialize(guid:, files:)
        super(guid: guid)
        @files = files
      end

      def as_json
        super.tap do |json|
          json[:type] = "missing_files"
          json[:files] = files.map(&:to_s)
        end
      end

      def valid?
        super && !files.empty?
      end
    end

    # Result to indicate that processor raises an exception.
    # Client programs should not return this result.
    class Error < Base
      # @dynamic exception
      attr_reader :exception

      def initialize(guid:, exception:)
        super(guid: guid)
        @exception = exception
      end

      def as_json
        super.tap do |json|
          json[:type] = 'error'
          json[:class] = exception.class.name
          json[:backtrace] = exception.backtrace
          json[:inspect] = exception.inspect
        end
      end

      def valid?
        super && exception.is_a?(Exception)
      end
    end
  end
end
