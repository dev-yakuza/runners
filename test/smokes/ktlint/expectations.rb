Smoke = Runners::Testing::Smoke

Smoke.add_test(
  "cli",
  {
    guid: "test-guid",
    timestamp: :_,
    type: "success",
    analyzer: { name: 'ktlint', version: "0.35.0" },
    issues: [
      {
        id: "7c8346bd",
        path: "src/Foo.kt",
        location: { start_line: 1 },
        message: "Not a valid Kotlin file (expecting a top level declaration) (cannot be auto-corrected)",
        links: [],
        object: nil,
      },
      {
        id: "indent",
        path: "src/App.kt",
        location: { start_line: 8 },
        message: "Unexpected indentation (2) (it should be 4) (cannot be auto-corrected)",
        links: [],
        object: nil,
      },
      {
        id: "indent",
        path: "src/App.kt",
        location: { start_line: 9 },
        message: "Unexpected indentation (12) (it should be 6) (cannot be auto-corrected)",
        links: [],
        object: nil,
      }
    ],
  }
)

Smoke.add_test(
  "cli_with_options",
  {
    guid: "test-guid",
    timestamp: :_,
    type: "success",
    analyzer: { name: 'ktlint', version: "0.35.0" },
    issues: [
      {
        id: "experimental:package-name",
        path: "src/App.kt",
        location: { start_line: 1 },
        message: "Package name must not contain underscore (cannot be auto-corrected)",
        links: [],
        object: nil,
      },
      {
        id: "no-semi",
        path: "src/App.kt",
        location: { start_line: 6 },
        message: "Unnecessary semicolon",
        links: [],
        object: nil,
      },
    ],
  }
)

Smoke.add_test(
  "gradle",
  {
    guid: "test-guid",
    timestamp: :_,
    type: "success",
    analyzer: { name: 'ktlint', version: "0.34.0" },
    issues: [
      {
        id: "0ebc0f91",
        path: "src/main/kotlin/gradle/App.kt",
        location: { start_line: 9 },
        message: "Unexpected indentation (12) (it should be 6) (cannot be auto-corrected)",
        links: [],
        object: nil,
      },
      {
        id: "5e2630c4",
        path: "src/main/kotlin/gradle/App.kt",
        location: { start_line: 8 },
        message: "Unexpected indentation (2) (it should be 4) (cannot be auto-corrected)",
        links: [],
        object: nil,
      },
    ],
  }
)

Smoke.add_test(
  "gradle_ktlint-gradle-plugin",
  {
    guid: "test-guid",
    timestamp: :_,
    type: "success",
    analyzer: { name: 'ktlint', version: "0.34.0" },
    issues: [
      {
        id: "experimental:indent",
        path: "src/main/kotlin/gradle/App.kt",
        location: { start_line: 10 },
        message: "Unexpected indentation (6) (should be 4)",
        links: [],
        object: nil,
      },
      {
        id: "indent",
        path: "src/main/kotlin/gradle/App.kt",
        location: { start_line: 10 },
        message: "Unexpected indentation (6) (it should be 8) (cannot be auto-corrected)",
        links: [],
        object: nil,
      }
    ],
  }
)

Smoke.add_test(
  "maven",
  {
    guid: "test-guid",
    timestamp: :_,
    type: "success",
    analyzer: { name: 'ktlint', version: "0.34.0" },
    issues: [
      {
        id: "indent",
        path: "src/main/App.kt",
        location: { start_line: 8 },
        message: "Unexpected indentation (2) (it should be 4) (cannot be auto-corrected)",
        links: [],
        object: nil,
      },
      {
        id: "indent",
        path: "src/main/App.kt",
        location: { start_line: 9 },
        message: "Unexpected indentation (12) (it should be 6) (cannot be auto-corrected)",
        links: [],
        object: nil,
      }
    ],
  }
)

Smoke.add_test("broken_sider_yml", {
  guid: "test-guid",
  timestamp: :_,
  type: "failure",
  analyzer: nil,
  message: "Invalid configuration in `sider.yml`: unknown attribute at config: `$.linter.ktlint`"
})
