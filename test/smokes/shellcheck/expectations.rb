Smoke = Runners::Testing::Smoke

Smoke.add_test("success", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC2006",
      path: "test_script",
      location: { start_line: 3, start_column: 3, end_line: 3, end_column: 8 },
      message: "Use $(...) notation instead of legacy backticked `...`.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2006"],
      object: {
        code: 2006,
        severity: "style",
        fix: { replacements: :_ },
      },
    },
    {
      id: "SC2020",
      path: "test.bash",
      location: { start_line: 3, start_column: 25, end_line: 3, end_column: 32 },
      message: "tr replaces sets of chars, not words (mentioned due to duplicates).",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2020"],
      object: {
        code: 2020,
        severity: "info",
        fix: nil,
      },
    },
    {
      id: "SC2034",
      path: "test-bats",
      location: { start_line: 3, start_column: 1, end_line: 3, end_column: 2 },
      message: "a appears unused. Verify use (or export if used externally).",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2034"],
      object: {
        code: 2034,
        severity: "warning",
        fix: nil,
      },
    },
    {
      id: "SC2034",
      path: "test.ksh",
      location: { start_line: 3, start_column: 1, end_line: 3, end_column: 7 },
      message: "arr appears unused. Verify use (or export if used externally).",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2034"],
      object: {
        code: 2034,
        severity: "warning",
        fix: nil,
      },
    },
    {
      id: "SC2039",
      path: "test.sh",
      location: { start_line: 3, start_column: 1, end_line: 3, end_column: 17 },
      message: "In POSIX sh, [[ ]] is undefined.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2039"],
      object: {
        code: 2039,
        severity: "warning",
        fix: nil,
      },
    },
    {
      id: "SC2060",
      path: "test.dash",
      location: { start_line: 3, start_column: 8, end_line: 3, end_column: 17 },
      message: "Quote parameters to tr to prevent glob expansion.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2060"],
      object: {
        code: 2060,
        severity: "warning",
        fix: nil,
      },
    },
    {
      id: "SC2086",
      path: "test.bats",
      location: { start_line: 5, start_column: 5, end_line: 5, end_column: 12 },
      message: "Double quote to prevent globbing and word splitting.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2086"],
      object: {
        code: 2086,
        severity: "info",
        fix: {
          replacements: [
            {
              line: 5,
              column: 5,
              endLine: 5,
              endColumn: 5,
              precedence: 12,
              insertionPoint: "afterEnd",
              replacement: '"',
            },
            {
              line: 5,
              column: 12,
              endLine: 5,
              endColumn: 12,
              precedence: 12,
              insertionPoint: "beforeStart",
              replacement: '"',
            },
          ],
        },
      },
    },
    {
      id: "SC2162",
      path: "src/test_script2",
      location: { start_line: 4, start_column: 1, end_line: 4, end_column: 5 },
      message: "read without -r will mangle backslashes.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2162"],
      object: {
        code: 2162,
        severity: "info",
        fix: nil,
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("shellcheckrc", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC1091",
      path: "test.bash",
      location: { start_line: 7, start_column: 3, end_line: 7, end_column: 9 },
      message: "Not following: lib.sh was not specified as input (see shellcheck -x).",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC1091"],
      object: {
        code: 1091,
        severity: "info",
        fix: nil,
      },
    },
    {
      id: "SC2249",
      path: "test.bash",
      location: { start_line: 3, start_column: 1, end_line: 3, end_column: 36 },
      message: "Consider adding a default *) case, even if it just exits with error.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2249"],
      object: {
        code: 2249,
        severity: "info",
        fix: nil,
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("no_files", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("option_target", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC1113",
      path: "src/test.sh",
      location: { start_line: 1, start_column: 2, end_line: 1, end_column: 2 },
      message: "Use #!, not just #, for the shebang.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC1113"],
      object: {
        code: 1113,
        severity: "error",
        fix: nil,
      },
    },
    {
      id: "SC1113",
      path: "test.bash",
      location: { start_line: 1, start_column: 2, end_line: 1, end_column: 2 },
      message: "Use #!, not just #, for the shebang.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC1113"],
      object: {
        code: 1113,
        severity: "error",
        fix: nil,
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("option_target_complex", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC2034",
      path: "test.sh",
      location: { start_line: 3, start_column: 1, end_line: 3, end_column: 4 },
      message: "foo appears unused. Verify use (or export if used externally).",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2034"],
      object: {
        code: 2034,
        severity: "warning",
        fix: nil,
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("option_include", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC2104",
      path: "test.bash",
      location: { start_line: 6, start_column: 5, end_line: 6, end_column: 10 },
      message: "In functions, use return instead of break.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2104"],
      object: {
        code: 2104,
        severity: "error",
        fix: nil,
      },
    },
    {
      id: "SC2105",
      path: "test.bash",
      location: { start_line: 13, start_column: 5, end_line: 13, end_column: 10 },
      message: "break is only valid in loops.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2105"],
      object: {
        code: 2105,
        severity: "error",
        fix: nil,
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("option_exclude", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC2034",
      path: "test.bash",
      location: { start_line: 12, start_column: 5, end_line: 12, end_column: 12 },
      message: "verbose appears unused. Verify use (or export if used externally).",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2034"],
      object: {
        code: 2034,
        severity: "warning",
        fix: nil,
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("option_enable", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC2248",
      path: "test.bash",
      location: { start_line: 6, start_column: 6, end_line: 6, end_column: 10 },
      message: "Prefer double quoting even when variables don't contain special characters.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2248"],
      object: {
        code: 2248,
        severity: "style",
        fix: { replacements: :_ },
      },
    },
    {
      id: "SC2249",
      path: "test.bash",
      location: { start_line: 3, start_column: 1, end_line: 3, end_column: 36 },
      message: "Consider adding a default *) case, even if it just exits with error.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2249"],
      object: {
        code: 2249,
        severity: "info",
        fix: nil,
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("option_enable_all", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC2248",
      path: "test.bash",
      location: { start_line: 6, start_column: 6, end_line: 6, end_column: 10 },
      message: "Prefer double quoting even when variables don't contain special characters.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2248"],
      object: {
        code: 2248,
        severity: "style",
        fix: { replacements: :_ },
      },
    },
    {
      id: "SC2249",
      path: "test.bash",
      location: { start_line: 3, start_column: 1, end_line: 3, end_column: 36 },
      message: "Consider adding a default *) case, even if it just exits with error.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2249"],
      object: {
        code: 2249,
        severity: "info",
        fix: nil,
      },
    },
    {
      id: "SC2250",
      path: "test.bash",
      location: { start_line: 6, start_column: 6, end_line: 6, end_column: 10 },
      message: "Prefer putting braces around variable references even when not strictly required.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2250"],
      object: {
        code: 2250,
        severity: "style",
        fix: { replacements: :_ },
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("option_shell", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC2039",
      path: "test.bash",
      location: { start_line: 3, start_column: 1, end_line: 3, end_column: 12 },
      message: "In POSIX sh, [[ ]] is undefined.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2039"],
      object: {
        code: 2039,
        severity: "warning",
        fix: nil,
      },
    },
    {
      id: "SC2039",
      path: "test.sh",
      location: { start_line: 1, start_column: 1, end_line: 1, end_column: 12 },
      message: "In POSIX sh, [[ ]] is undefined.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2039"],
      object: {
        code: 2039,
        severity: "warning",
        fix: nil,
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("option_severity", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [
    {
      id: "SC2104",
      path: "test.bash",
      location: { start_line: 6, start_column: 5, end_line: 6, end_column: 10 },
      message: "In functions, use return instead of break.",
      links: ["https://github.com/koalaman/shellcheck/wiki/SC2104"],
      object: {
        code: 2104,
        severity: "error",
        fix: nil,
      },
    },
  ],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})

Smoke.add_test("option_norc", {
  guid: "test-guid",
  timestamp: :_,
  type: "success",
  issues: [],
  analyzer: { name: "ShellCheck", version: "0.7.0" },
})
