module Runners
  class Processor::MetricsFileInfo < Processor
    SCHEMA = _ = StrongJSON.new do
      extend Schema::ConfigTypes

      # @type self: SchemaClass
      let :config, metrics

      let :issue, object(
        lines_of_code: integer?,
        last_committed_at: string,
        number_of_commits: integer,
        occurrence: integer,
        additions: integer,
        deletions: integer
      )
    end

    # The Schema::Config.register() method checks for multiple registration, so we can register only one schema named `metrics`.
    # There is no need to define the `metrics` schema nor register it in Processor::MetricsComplexity and Processor::MetricsCodeClone.
    register_config_schema SCHEMA.config, name: :metrics

    # Basically, the code churn is the number of times or the sum of added/deleted lines a file has changed within a specified period of time.
    # Like other products, we adopt the last 90 days before the latest commit date. However, if a project is not so active and has only
    # a few commits in a month, the churn values fluctuate on the scatter plot (churn v.s quality metrics) due to ambiguity of the small number of commits.
    # A relative value of churn becomes stable as comparing the values across a certain number of files. So we also take 100 commits into account
    # when there are not enough commits in 90 days.
    CHURN_PERIOD_IN_DAYS = 90
    CHURN_COMMIT_COUNT = 100

    def default_analyzer_version
      Runners::VERSION
    end

    # This analyser use git metadata (.git/).
    def use_git_metadata_dir?
      true
    end

    def analyze(changes)
      # Generate pre-computed cache for Git metadata access (https://git-scm.com/docs/git-commit-graph)
      # This improves the performance of access to Git metadata for a large repository.
      # You can see the efficacy here: https://github.com/sider/runners/issues/2028#issuecomment-776534408
      trace_writer.message "Generating pre-computed Git metadata cache..." do
        git("commit-graph", "write", "--reachable", "--changed-paths")
      end

      target_files = Pathname.glob("**/*", File::FNM_DOTMATCH).filter do |path|
        path.file? && !path.fnmatch?(".git/**", File::FNM_DOTMATCH)
      end

      analyze_last_committed_at(target_files)
      analyze_lines_of_code(target_files)
      number_of_commits = analyze_code_churn

      Results::Success.new(
        guid: guid,
        analyzer: analyzer,
        issues: target_files.map { |path| generate_issue(path, number_of_commits) }
      )
    end

    private

    def generate_issue(path, number_of_commits)
      loc = lines_of_code[path]
      commit = last_committed_at.fetch(path)
      churn = code_churn.fetch(path, { occurrence: 0, additions: 0, deletions: 0 })

      Issue.new(
        path: path,
        location: nil,
        id: "metrics_fileinfo",
        message: "#{path}: loc = #{loc || "(no info)"}, last commit datetime = #{commit}",
        object: {
          lines_of_code: loc,
          last_committed_at: commit,
          number_of_commits: number_of_commits,
          occurrence: churn[:occurrence],
          additions: churn[:additions],
          deletions: churn[:deletions]
        },
        schema: SCHEMA.issue
      )
    end

    def lines_of_code
      @lines_of_code ||= {}
    end

    def analyze_lines_of_code(targets)
      trace_writer.message "Analyzing line of code..." do
        extract_text_files(targets).each_slice(1000) do |files|
          stdout, _ = capture3!("wc", "-l", *files, trace_stdout: false, trace_command_line: false)
          lines = stdout.lines(chomp: true)

          # `wc` command outputs total count when we pass multiple targets. remove it if exist
          lines.pop if lines.last&.match?(/^\d+ total$/)

          lines.each do |line|
            fields = line.split(" ")
            loc = (fields[0] or raise)
            fname = (fields[1] or raise)
            lines_of_code[Pathname(fname)] = Integer(loc)
          end
        end
      end
    end

    def last_committed_at
      @last_committed_at ||= {}
    end

    def parse_commit_line(commit_line)
      # Parse single* commit record from `git log -z`, where separator is \0\0
      #
      # Sample git log -z ... output could look like this.
      # Note that there are 5 commits here, and 2 of them are empty.
      #
      # *The `commit_line` argument has a bit vague meaning here, since in case of line two, it can "contain" the commits.
      # The reason is that empty commit "stick" to next commit in the output (they are not properly divided by \0\0)
      #
      # 2021-12-20T12:51:39+09:00\nC\0\0
      # 2021-12-20T12:51:28+09:00\02021-12-20T12:51:09+09:00\nB\0\0
      # 2021-12-20T12:50:58+09:00\nA\0\0
      # 2021-12-20T12:50:35+09:00
      date, files_str = commit_line.split("\n", 2)
      raise "Commit date could not be determined." if date.nil?

      date = date.split("\0")[-1]  # commits with no filechanges stick to the next commit in output, pick the right one
      files_str = files_str || ""  # in case commit has no changed files, files_str could be nil
      [date, files_str.split("\0")]
    end

    def datemax(first, second)
      # Return the greater (later) of two iso8601 date strings, with empty string always counting as earlier one
      return second if first == ""
      return first if second == ""

      # compare date strings while also taking care of timezones
      Time.parse(first) < Time.parse(second) ? second : first
    end

    def analyze_last_committed_at(targets)
      trace_writer.message "Analyzing last commit time..." do

        # mark which files currently exist, so we don't records dates of deleted files
        for target in targets do
          last_committed_at[target] = ""
        end

        # Read the entire commit history in bulk, and process it on Ruby side.
        # This is around 30-times faster than calling git log for each file separately.
        stdout, _ = git("log", "--format=format:%aI", "--name-only", "-z")
        stdout.split("\0\0").each do |commit|
          date, files = parse_commit_line(commit)
          # for each changed line in a commit
          for file in files do
            filepath = Pathname.new(file)
            # track only current files (ignore deleted ones)
            if last_committed_at.key?(filepath)
              # if a file was modified, and it's newer than current value, update it
              last_committed_at[filepath] = datemax(last_committed_at[filepath], date)
            end
          end
        end
      end
    end

    def code_churn
      @code_churn ||= {}
    end

    def analyze_code_churn
      trace_writer.message "Analyzing code churn..." do
        commits_by_num = commit_summary_within("--max-count", CHURN_COMMIT_COUNT.to_s)
        days_ago = (commits_by_num[:latest_time] - CHURN_PERIOD_IN_DAYS * 60 * 60 * 24).iso8601
        commits_by_time = commit_summary_within("--since", days_ago)
        outlive_commits = commits_by_num[:count] > commits_by_time[:count] ? commits_by_num : commits_by_time

        stdout, _ = git("log", "--reverse", "--format=format:#", "--numstat", "#{outlive_commits[:oldest_sha]}..HEAD")
        lines = stdout.lines(chomp: true)
        number_of_commits = lines.count("#")

        lines.each do |line|
          adds, dels, fname = line.split("\t")
          if adds && dels && fname
            fname = Pathname(fname)
            code_churn[fname] = calc_churn(code_churn[fname], adds, dels)
          end
        end

        number_of_commits
      end
    end

    def calc_churn(churn, adds, dels)
      churn ||= { occurrence: 0, additions: 0, deletions: 0 }
      churn[:occurrence] += 1
      churn[:additions] += adds == "-" ? 0 : Integer(adds)
      churn[:deletions] += dels == "-" ? 0 : Integer(dels)
      churn
    end

    def commit_summary_within(*args_range)
      stdout, _ = git("log", "--format=format:%H|%cI", *args_range)
      lines = stdout.lines(chomp: true)
      latest_line = lines.first or raise "Required log line: #{lines.size} lines"
      oldest_line = lines.last or raise "Required log line: #{lines.size} lines"
      latest_sha, latest_time = latest_line.split("|")
      oldest_sha, oldest_time = oldest_line.split("|")
      raise "Required sha in the latest line: #{latest_line}" unless latest_sha
      raise "Required time in the latest line: #{latest_line}" unless latest_time
      raise "Required sha in the oldest line: #{oldest_line}" unless oldest_sha
      raise "Required time in the oldest line: #{oldest_line}" unless oldest_time
      {
        count: lines.size,
        latest_sha: latest_sha,
        latest_time: Time.parse(latest_time),
        oldest_sha: oldest_sha,
        oldest_time: Time.parse(oldest_time),
      }
    end

    # There may not be a perfect method to discriminate file type.
    # We determined to use 'git ls-file' command with '--eol' option based on an evaluation.
    #  the target methods: mimemagic library, file(1) command, git ls-files --eol.
    #
    # 1. mimemagic library (https://rubygems.org/gems/mimemagic/)
    # Pros:
    #   * A Gem library. We can install easily.
    #   * It seems to be well-maintained now.
    # Cons:
    #   * This library cannot distinguish between a plain text file and a binary file.
    #
    # 2. file(1) command (https://linux.die.net/man/1/file)
    # Pros:
    #   * This is a well-known method to inspect file type.
    # Cons:
    #   * We have to install an additional package on devon_rex_base.
    #   * File type classification for plain text is too detailed. File type string varies based on the target file encoding.
    #     * e.g.  ASCII text, ISO-8859 text, ASCII text with escape sequence, UTF-8 Unicode text, Non-ISO extended-ASCII test, and so on.
    #
    # 3. git ls-files --eol (See: https://git-scm.com/docs/git-ls-files#Documentation/git-ls-files.txt---eol)
    #  Pros:
    #    * We don't need any additional packages.
    #    * It output whether the target file is text or not. (This is the information we need)
    #    * The output is reliable to some extent because Git is a very well maintained and used OSS product.
    #  Cons:
    #    * (no issue found)
    #
    # We've tested some ambiguous cases in binary_files, multi_language, and unknown_extension smoke test cases.
    # We can determine file type correctly in cases as below.
    #  * A plain text file having various extensions (.txt, .rb, .md, etc..)
    #  * A binary file having various extensions (.png, .data, etc...)
    #  * A binary file, but having .txt extension. (e.g. no_text.txt)
    #  * A text files not encoded in UTF-8 but EUC-JP, ISO-2022-JP, Shift JIS.
    #  * A text file having a non-well-known extension. (e.g. foo.my_original_extension )
    def extract_text_files(targets)
      text_files = Set[]

      targets.each_slice(1000) do |files|
        stdout, _stderr = git("ls-files", "--eol", "--error-unmatch", "-z", "--", *files)
        stdout.each_line("\0", chomp: true) do |line|
          # NOTE: A simple splitting by spaces does not work, e.g. `text eol=lf`.
          #
          # @see https://git-scm.com/docs/git-ls-files#_output
          # @see https://git-scm.com/docs/git-ls-files#Documentation/git-ls-files.txt---eol
          fields, file = line.split("\t", 2)
          next if fields.nil? || file.nil?

          _i_eol, w_eol, _ignored = fields.split(" ", 3)
          if w_eol != "w/-text"
            text_files << Pathname(file)
          end
        end
      end

      text_files
    end

    def git(*args)
      capture3!("git", *args, trace_stdout: false, trace_command_line: false)
    end
  end
end
