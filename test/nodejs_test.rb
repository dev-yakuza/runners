require_relative 'test_helper'

class NodejsTest < Minitest::Test
  include TestHelper

  Constraint = Runners::Nodejs::Constraint
  Dependency = Runners::Nodejs::Dependency
  DefaultDependencies = Runners::Nodejs::DefaultDependencies
  InvalidDefaultDependencies = Runners::Nodejs::InvalidDefaultDependencies
  ConstraintsNotSatisfied = Runners::Nodejs::ConstraintsNotSatisfied
  NpmInstallFailed = Runners::Nodejs::NpmInstallFailed
  YarnInstallFailed = Runners::Nodejs::YarnInstallFailed

  def processor_class
    @processor_class ||= Class.new(Runners::Processor) do
      include Runners::Nodejs

      def analyzer_bin
        "eslint"
      end
    end
  end

  def trace_writer
    @trace_writer ||= Runners::TraceWriter.new(writer: [])
  end

  def actual_commands
    trace_writer.writer.map { |entry| entry[:command_line] }.compact
  end

  def actual_errors
    trace_writer.writer.select { |entry| entry[:trace] == "error" }.map { |entry| entry[:message] }
  end

  def new_processor(working_dir:)
    processor_class.new(
      guid: SecureRandom.uuid,
      working_dir: working_dir,
      git_ssh_path: nil,
      trace_writer: trace_writer,
    )
  end

  def stub_const(name, value)
    begin
      saved_value = Runners::Nodejs.const_get(name)
      silence_warnings { Runners::Nodejs.const_set(name, value) }
      yield
    ensure
      silence_warnings { Runners::Nodejs.const_set(name, saved_value) }
    end
  end

  def test_nodejs_analyzer_local_command
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      assert_equal "node_modules/.bin/eslint", processor.nodejs_analyzer_local_command
    end
  end

  def test_nodejs_analyzer_bin
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      assert_equal "eslint", processor.nodejs_analyzer_bin

      (path / "node_modules/.bin").mkpath
      (path / "node_modules/.bin/eslint").write("")
      assert_equal "node_modules/.bin/eslint", processor.nodejs_analyzer_bin
    end
  end

  def test_analyzer_version_with_global
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      processor.stub :nodejs_analyzer_locally_installed?, false do
        processor.stub :nodejs_analyzer_global_version, "1.0.0" do
          assert_equal "1.0.0", processor.analyzer_version
        end
      end
    end
  end

  def test_analyzer_version_with_local
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      processor.stub :nodejs_analyzer_locally_installed?, true do
        processor.stub :nodejs_analyzer_local_version, "2.0.0" do
          assert_equal "2.0.0", processor.analyzer_version
        end
      end
    end
  end

  def test_package_json_path
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      assert_equal(path / "package.json", processor.package_json_path)
    end
  end

  def test_package_json
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      assert_raises Errno::ENOENT do
        processor.package_json
      end

      (path / "package.json").write(JSON.generate(name: "foo", version: "1.0.0", number: 999, bool: false))
      assert_equal({ name: "foo", version: "1.0.0", number: 999, bool: false }, processor.package_json)
    end
  end

  def test_package_lock_json_path
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      assert_equal(path / "package-lock.json", processor.package_lock_json_path)
    end
  end

  def test_yarn_lock_path
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      assert_equal(path / "yarn.lock", processor.yarn_lock_path)
    end
  end

  def test_install_nodejs_deps
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      deps = { "eslint" => "5.0.0", "eslint-plugin-react" => "7.10.0" }
      processor.package_json_path.write(JSON.generate(devDependencies: deps))

      defaults = DefaultDependencies.new(
        main: Dependency.new(name: "eslint", version: "5.15.0"),
        extras: [
          Dependency.new(name: "eslint-plugin-react", version: "7.14.2"),
        ],
      )

      constraints = {
        "eslint" => Constraint.new(">= 5.0.0", "< 7.0.0"),
        "eslint-plugin-react" => Constraint.new(">= 4.2.1", "< 8.0.0"),
      }

      option = Runners::Nodejs::INSTALL_OPTION_ALL

      processor.stub :nodejs_analyzer_global_version, defaults.main.version do
        processor.install_nodejs_deps(defaults, constraints: constraints, install_option: option)

        stdout, _ = processor.capture3!(processor.nodejs_analyzer_bin, "-v")
        assert_equal "v5.0.0\n", stdout

        assert_equal(0, trace_writer.writer.count { |e| e[:trace] == "warning" })
      end
    end
  end

  def test_install_nodejs_deps_with_option_nil
    mktmpdir do |path|
      defaults = DefaultDependencies.new(main: Dependency.new(name: "eslint", version: "5.15.0"))
      constraints = { "eslint" => Constraint.new(">= 5.0.0", "< 7.0.0") }
      option = nil

      # Without package.json
      processor = new_processor(working_dir: path)
      processor.stub :nodejs_analyzer_global_version, "5.15.0" do
        processor.install_nodejs_deps(defaults, constraints: constraints, install_option: option)
        refute processor.package_json_path.exist?
        assert_equal "5.15.0", processor.analyzer_version
      end

      # With package.json
      processor = new_processor(working_dir: path)
      processor.stub :nodejs_analyzer_global_version, "5.15.0" do
        processor.package_json_path.write(JSON.generate(dependencies: { "eslint" => "6.0.0" }))
        processor.install_nodejs_deps(defaults, constraints: constraints, install_option: option)
        assert processor.package_json_path.exist?
        assert_equal "6.0.0", processor.analyzer_version
      end
    end
  end

  def test_install_nodejs_deps_with_option_none
    mktmpdir do |path|
      defaults = DefaultDependencies.new(main: Dependency.new(name: "eslint", version: "5.15.0"))
      constraints = { "eslint" => Constraint.new(">= 5.0.0", "< 7.0.0") }
      option = Runners::Nodejs::INSTALL_OPTION_NONE

      # Without package.json
      processor = new_processor(working_dir: path)
      processor.stub :nodejs_analyzer_global_version, "5.15.0" do
        processor.install_nodejs_deps(defaults, constraints: constraints, install_option: option)
        refute processor.package_json_path.exist?
        assert_equal "5.15.0", processor.analyzer_version
      end

      # With package.json
      processor = new_processor(working_dir: path)
      processor.stub :nodejs_analyzer_global_version, "5.15.0" do
        processor.package_json_path.write(JSON.generate(dependencies: { "eslint" => "6.0.0" }))
        processor.install_nodejs_deps(defaults, constraints: constraints, install_option: option)
        assert processor.package_json_path.exist?
        assert_equal "5.15.0", processor.analyzer_version
      end
    end
  end

  def test_install_nodejs_deps_using_yarn
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      processor.package_json_path.write(JSON.generate(dependencies: { "eslint" => "6.0.1" }))
      FileUtils.cp data("yarn.lock"), processor.yarn_lock_path

      defaults = DefaultDependencies.new(
        main: Dependency.new(name: "eslint", version: "5.15.0"),
      )
      constraints = {
        "eslint" => Constraint.new(">= 5.0.0", "< 7.0.0"),
      }
      option = Runners::Nodejs::INSTALL_OPTION_ALL

      processor.stub :nodejs_analyzer_global_version, "5.15.0" do
        processor.install_nodejs_deps(defaults, constraints: constraints, install_option: option)

        stdout, _ = processor.capture3!(processor.nodejs_analyzer_bin, "-v")
        assert_equal "v6.0.1\n", stdout

        assert_equal(0, trace_writer.writer.count { |e| e[:trace] == "warning" })
      end
    end
  end

  def test_install_nodejs_deps_with_duplicate_lockfiles
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      processor.package_json_path.write(JSON.generate(dependencies: { "eslint" => "6.0.1" }))
      FileUtils.cp data("yarn.lock"), processor.yarn_lock_path
      FileUtils.cp data("package-lock.json"), processor.package_lock_json_path

      defaults = DefaultDependencies.new(
        main: Dependency.new(name: "eslint", version: "5.15.0"),
      )
      constraints = {
        "eslint" => Constraint.new(">= 5.0.0", "< 7.0.0"),
      }
      option = Runners::Nodejs::INSTALL_OPTION_ALL

      processor.stub :nodejs_analyzer_global_version, "5.15.0" do
        processor.install_nodejs_deps(defaults, constraints: constraints, install_option: option)

        stdout, _ = processor.capture3!(processor.nodejs_analyzer_bin, "-v")
        assert_equal "v6.0.1\n", stdout

        expected_warning =
          "Two lock files `package-lock.json` and `yarn.lock` are found. " \
          "Sider uses `yarn.lock` in this case, but please consider deleting either file for more accurate analysis."
        actual_warnings = trace_writer.writer.select { |e| e[:trace] == "warning" }.map { |e| e[:message] }
        assert_equal [expected_warning], actual_warnings
      end
    end
  end

  def test_check_nodejs_default_deps
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      defaults = DefaultDependencies.new(
        main: Dependency.new(name: "eslint", version: "5.15.0"),
      )

      processor.stub :nodejs_analyzer_global_version, "5.15.0" do
        processor.send(:check_nodejs_default_deps, defaults, {})
        pass "with an empty constraint"

        constraints = { "eslint" => Constraint.new(">= 5.0.0", "< 7.0.0") }
        processor.send(:check_nodejs_default_deps, defaults, constraints)
        pass "with a range constraint"

        constraints = { "eslint" => Constraint.new(">= 5.15.0") }
        processor.send(:check_nodejs_default_deps, defaults, constraints)
        pass "with a minimum constraint"

        constraints = { "eslint" => Constraint.new("<= 5.15.0") }
        processor.send(:check_nodejs_default_deps, defaults, constraints)
        pass "with a maximum constraint"

        constraints = { "eslint" => Constraint.new("= 5.15.0") }
        processor.send(:check_nodejs_default_deps, defaults, constraints)
        pass "with a equal constraint"

        constraints = { "eslint" => Constraint.new("> 5.15.0") }
        error = assert_raises InvalidDefaultDependencies do
          processor.send(:check_nodejs_default_deps, defaults, constraints)
        end
        assert_equal "The default dependency `eslint@5.15.0` must satisfy the constraint `> 5.15.0`", error.message

        constraints = { "eslint" => Constraint.new(">= 5.0.0", "< 5.15.0") }
        error = assert_raises InvalidDefaultDependencies do
          processor.send(:check_nodejs_default_deps, defaults, constraints)
        end
        assert_equal "The default dependency `eslint@5.15.0` must satisfy the constraint `>= 5.0.0, < 5.15.0`", error.message
      end

      processor.stub :nodejs_analyzer_global_version, "1.0.0" do
        error = assert_raises InvalidDefaultDependencies do
          processor.send(:check_nodejs_default_deps, defaults, { "eslint" => Constraint.new("= 5.15.0") })
        end
        assert_equal "The default dependency `eslint` version must be `5.15.0`, but actually `1.0.0`", error.message
      end
    end
  end

  def test_npm_install
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      node_modules = path / "node_modules"
      typescript = node_modules / "typescript"

      package_json = {
        dependencies: { "typescript" => "3.5.3" },
        scripts: { "postinstall" => "exit 1" },
        engines: { "node" => "8.0.0" },
      }
      processor.package_json_path.write(JSON.generate(package_json))
      (path / ".npmrc").write("engine-strict = true")

      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_NONE)
      refute node_modules.exist?

      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_ALL)
      assert typescript.exist?

      node_modules.rmtree
      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_PRODUCTION)
      assert typescript.exist?

      node_modules.rmtree
      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_DEVELOPMENT)
      refute node_modules.exist?

      processor.package_json_path.write(JSON.generate(devDependencies: { "typescript" => "3.5.3" }))
      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_DEVELOPMENT)
      assert typescript.exist?

      expected_commands = [
        %w[npm install --ignore-scripts --progress=false --engine-strict=false --package-lock=false],
        %w[npm install --ignore-scripts --progress=false --engine-strict=false --package-lock=false --only=production],
        %w[npm install --ignore-scripts --progress=false --engine-strict=false --package-lock=false --only=development],
        %w[npm install --ignore-scripts --progress=false --engine-strict=false --package-lock=false --only=development],
      ]
      assert_equal expected_commands, actual_commands
    end
  end

  def test_npm_install_using_ci
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      node_modules = path / "node_modules"
      typescript = node_modules / "typescript"

      processor.package_json_path.write(JSON.generate(dependencies: { "typescript" => "3.5.3" }))
      FileUtils.cp data("package-lock.json"), processor.package_lock_json_path

      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_ALL)
      assert typescript.exist?

      node_modules.rmtree
      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_PRODUCTION)
      assert typescript.exist?

      node_modules.rmtree
      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_DEVELOPMENT)
      refute typescript.exist?

      processor.package_json_path.write(JSON.generate(devDependencies: { "typescript" => "3.5.3" }))
      FileUtils.cp data("package-lock.dev.json"), processor.package_lock_json_path

      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_ALL)
      assert typescript.exist?

      node_modules.rmtree
      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_PRODUCTION)
      refute typescript.exist?

      processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_DEVELOPMENT)
      assert typescript.exist?

      expected_commands = [
        %w[npm ci --ignore-scripts --progress=false --engine-strict=false],
        %w[npm ci --ignore-scripts --progress=false --engine-strict=false --only=production],
        %w[npm install --ignore-scripts --progress=false --engine-strict=false --only=development --package-lock=false],
        %w[npm ci --ignore-scripts --progress=false --engine-strict=false],
        %w[npm ci --ignore-scripts --progress=false --engine-strict=false --only=production],
        %w[npm install --ignore-scripts --progress=false --engine-strict=false --only=development --package-lock=false],
      ]
      assert_equal expected_commands, actual_commands

      expected_warning = <<~MSG.strip
        The `npm ci --only=development` command does not install anything, so `npm install --only=development` will be used instead.
        If you want to use `npm ci`, please change your install option from `development` to `true`.
        For details about the npm behavior, see https://npm.community/t/npm-ci-only-dev-does-not-install-anything/3068
      MSG
      actual_warnings = trace_writer.writer.select { |e| e[:trace] == "warning" }.map { |e| e[:message] }
      assert_equal [expected_warning, expected_warning], actual_warnings
      assert_equal [
        { message: expected_warning, file: "package.json" },
        { message: expected_warning, file: "package.json" },
      ], processor.warnings
    end
  end

  def test_npm_install_failed
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      processor.package_json_path.write(JSON.generate(dependencies: { "foo" => "github:sider/foo" }))

      error = assert_raises NpmInstallFailed do
        processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_ALL)
      end
      expected_error_message = <<~MSG.strip
        `npm install` failed. Please check the log for details.
        If you want to explicitly disable the installation, please set `npm_install: false` on your `sider.yml`.
      MSG
      assert_equal expected_error_message, error.message
      assert_equal [expected_error_message], actual_errors
    end
  end

  def test_yarn_install
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      node_modules = path / "node_modules"
      eslint = node_modules / "eslint"

      processor.package_json_path.write(JSON.generate(dependencies: { "eslint" => "6.0.1" }))
      FileUtils.cp data("yarn.lock"), processor.yarn_lock_path

      processor.send(:yarn_install, Runners::Nodejs::INSTALL_OPTION_NONE)
      refute eslint.exist?

      processor.send(:yarn_install, Runners::Nodejs::INSTALL_OPTION_ALL)
      assert eslint.exist?

      eslint.rmtree
      processor.send(:yarn_install, Runners::Nodejs::INSTALL_OPTION_PRODUCTION)
      assert eslint.exist?

      node_modules.rmtree
      processor.send(:yarn_install, Runners::Nodejs::INSTALL_OPTION_DEVELOPMENT)
      assert eslint.exist?

      expected_commands = [
        %w[yarn install --ignore-engines --ignore-scripts --no-progress --non-interactive --frozen-lockfile],
        %w[yarn install --ignore-engines --ignore-scripts --no-progress --non-interactive --frozen-lockfile --production],
        %w[yarn install --ignore-engines --ignore-scripts --no-progress --non-interactive --frozen-lockfile],
      ]
      assert_equal expected_commands, actual_commands

      expected_warning = <<~MSG.strip
        Yarn does not have a same feature as `npm install --only=development`, so the option `development` will be ignored.
        See https://github.com/yarnpkg/yarn/issues/3254 for details.
      MSG
      actual_warnings = trace_writer.writer.select { |e| e[:trace] == "warning" }.map { |e| e[:message] }
      assert_equal [expected_warning], actual_warnings
      assert_equal [{ message: expected_warning, file: "yarn.lock" }], processor.warnings
    end
  end

  def test_yarn_install_failed
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      # 'yarn install' fails because of incorrect package settings between yarn.lock and package.json
      FileUtils.cp incorrect_yarn_data("yarn.lock"), processor.yarn_lock_path
      FileUtils.cp incorrect_yarn_data("package.json"), processor.package_json_path

      error = assert_raises YarnInstallFailed do
        processor.send(:yarn_install, Runners::Nodejs::INSTALL_OPTION_ALL)
      end
      expected_error_message = <<~MSG.strip
        `yarn install` failed. Please confirm `yarn.lock` is consistent with `package.json`.
      MSG
      assert_equal expected_error_message, error.message
      assert_equal [expected_error_message], actual_errors
    end
  end

  def test_check_installed_nodejs_deps
    mktmpdir do |path|
      processor = new_processor(working_dir: path)

      npm_install = ->(json) {
        processor.package_json_path.write(JSON.generate(json))
        processor.send(:npm_install, Runners::Nodejs::INSTALL_OPTION_ALL)
      }

      default = Dependency.new(name: "eslint", version: "5.1.0")
      constraints = { "eslint" => Constraint.new(">= 5.0.0") }

      npm_install.call(dependencies: {})
      processor.send(:check_installed_nodejs_deps, constraints, default)
      pass "when no dependencies"

      npm_install.call(dependencies: { "ci-info" => "2.0.0" })
      processor.send(:check_installed_nodejs_deps, constraints, default)
      pass "when no dependencies satisfying constraints"

      expected_error_message = <<~MSG.strip
        Your `eslint` settings could not satisfy the required constraints. Please check your `package.json` again.
        If you want to analyze via the Sider default settings, please configure your `sider.yml`. For details, see the documentation.
      MSG

      npm_install.call(dependencies: { "eslint-config-standard" => "10.0.0" })
      processor.send(:check_installed_nodejs_deps, constraints, default)
      pass expected_error_message

      npm_install.call(dependencies: { "eslint" => "4.0.0" })
      error = assert_raises ConstraintsNotSatisfied do
        processor.send(:check_installed_nodejs_deps, constraints, default)
      end
      assert_equal expected_error_message, error.message

      ### assert warnings output

      expected_warnings = [
        "No required dependencies for analysis were installed. Instead, the pre-installed `eslint@5.1.0` will be used.",
        "The required dependency `eslint` may not have been correctly installed. It may be a missing peer dependency."
      ]
      actual_warnings = trace_writer.writer.select { |e| e[:trace] == "warning" }.map { |e| e[:message] }
      assert_equal expected_warnings, actual_warnings
      assert_equal [
        { message: expected_warnings[0], file: "package.json" },
        { message: expected_warnings[1], file: "package.json" },
      ], processor.warnings

      expected_errors = [
        "The installed dependency `eslint@4.0.0` did not satisfy the constraint `>= 5.0.0`.",
        expected_error_message,
      ]
      assert_equal expected_errors, actual_errors
    end
  end
end
