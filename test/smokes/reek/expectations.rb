Smoke = Runners::Testing::Smoke

Smoke.add_test(
  'multiline',
  guid: 'test-guid',
  timestamp: :_,
  type: 'success',
  issues: [
    {
      path: 'cat.rb',
      location: {
        start_line: 4,
      },
      id: 'DuplicateMethodCall',
      message: "`Cat#self.call` calls 'self.new.call' 3 times",
      links: [
        'https://github.com/troessner/reek/blob/v5.5.0/docs/Duplicate-Method-Call.md'
      ],
      object: nil,
      git_blame_info: nil,
    },
    {
      path: 'cat.rb',
      location: {
        start_line: 5,
      },
      id: 'DuplicateMethodCall',
      message: "`Cat#self.call` calls 'self.new.call' 3 times",
      links: [
        'https://github.com/troessner/reek/blob/v5.5.0/docs/Duplicate-Method-Call.md'
      ],
      object: nil,
      git_blame_info: nil,
    },
    {
      path: 'cat.rb',
      location: {
        start_line: 6,
      },
      id: 'DuplicateMethodCall',
      message: "`Cat#self.call` calls 'self.new.call' 3 times",
      links: [
        'https://github.com/troessner/reek/blob/v5.5.0/docs/Duplicate-Method-Call.md'
      ],
      object: nil,
      git_blame_info: nil,
    },
  ],
  analyzer: {
    name: 'Reek',
    version: '5.5.0'
  }
)

Smoke.add_test(
    'recommend_config',
    guid: 'test-guid',
    timestamp: :_,
    type: 'success',
    issues: [
      {
        path: 'cat.rb',
        location: {
            start_line: 1,
        },
        id: 'ModuleInitialize',
        message: "`Cat` has initialize method",
        links: [
          'https://github.com/troessner/reek/blob/v5.5.0/docs/Module-Initialize.md'
        ],
        object: nil,
        git_blame_info: nil,
      },
    ],
    analyzer: {
        name: 'Reek',
        version: '5.5.0'
    }
)

Smoke.add_test(
  'syntax_error',
  {
    guid: 'test-guid',
    timestamp: :_,
    type: 'success',
    issues: [
      {
        path: 'cat.rb',
        location: {
            start_line: 1,
        },
        id: 'ModuleInitialize',
        message: "`Cat` has initialize method",
        links: [
          'https://github.com/troessner/reek/blob/v5.5.0/docs/Module-Initialize.md'
        ],
        object: nil,
        git_blame_info: nil,
      },
    ],
    analyzer: {
      name: 'Reek',
      version: '5.5.0'
    }
  },
  warnings: [
    { message: "Detected syntax error in `error.rb`", file: 'error.rb' }
  ]
)

Smoke.add_test(
  'exist_reek_config',
  guid: 'test-guid',
  timestamp: :_,
  type: 'success',
  issues: [
    {
      message: "`Summer#weekend` has 3 parameters",
      links: [
        "https://github.com/troessner/reek/blob/v5.5.0/docs/Long-Parameter-List.md"
      ],
      id: "LongParameterList",
      path: "summer.rb",
      location: {
        start_line: 7
      },
      object: nil,
      git_blame_info: nil,
    },
    {
      message: "`Summer#summer_vacation` performs a nil-check",
      links: ["https://github.com/troessner/reek/blob/v5.5.0/docs/Nil-Check.md"],
      id: "NilCheck",
      path: "summer.rb",
      location: {
        start_line: 12
      },
      object: nil,
      git_blame_info: nil,
    }
  ],
  analyzer: {
    name: 'Reek',
    version: '5.5.0'
  }
)

Smoke.add_test(
  'renamed_rule',
  guid: 'test-guid',
  timestamp: :_,
  type: 'error',
  class: 'Runners::Shell::ExecError',
  backtrace: :_,
  inspect: :_,
)

Smoke.add_test(
  'v4_config_style',
  guid: 'test-guid',
  timestamp: :_,
  type: 'error',
  class: 'Runners::Shell::ExecError',
  backtrace: :_,
  inspect: :_,
)

Smoke.add_test(
  'v4_config_file_exists',
  guid: 'test-guid',
  timestamp: :_,
  type: 'success',
  issues: [
    {
      message: "`WorldCup#europe` has 14 parameters",
      links: [
        "https://github.com/troessner/reek/blob/v5.5.0/docs/Long-Parameter-List.md"
      ],
      id: "LongParameterList",
      path: "world_cup.rb",
      location: {
        start_line: 3
      },
      object: nil,
      git_blame_info: nil,
    }
  ],
  analyzer: {
    name: 'Reek',
    version: '5.5.0'
  }
)

Smoke.add_test(
  'lowest_deps',
  guid: 'test-guid',
  timestamp: :_,
  type: 'success',
  issues: [
    {
      path: 'cat.rb',
      location: {
        start_line: 1,
      },
      id: 'ModuleInitialize',
      message: "`Cat` has initialize method",
      links: [
        'https://github.com/troessner/reek/blob/master/docs/Module-Initialize.md'
      ],
      object: nil,
      git_blame_info: nil,
    },
  ],
  analyzer: {
    name: 'Reek',
    version: '4.4.0'
  }
)

Smoke.add_test(
  'unsupported',
  {
    guid: 'test-guid',
    timestamp: :_,
    type: 'success',
    issues: [
      {
        path: 'cat.rb',
        location: {
          start_line: 1,
        },
        id: 'ModuleInitialize',
        message: "`Cat` has initialize method",
        links: [
          'https://github.com/troessner/reek/blob/v5.5.0/docs/Module-Initialize.md'
        ],
        object: nil,
        git_blame_info: nil,
      },
    ],
    analyzer: {
      name: 'Reek',
      version: '5.5.0',
    }
  },
  warnings: [
    { message: <<~MESSAGE, file: nil }
      Sider tried to install `reek 4.0.0` according to your `Gemfile.lock`, but it installs `5.5.0` instead.
      Because `4.0.0` does not satisfy the Sider constraints [\">= 4.4.0\", \"< 6.0\"].

      If you want to use a different version of `reek`, update your `Gemfile.lock` to satisfy the constraint or specify the gem version in your `sider.yml`.
      See https://help.sider.review/getting-started/custom-configuration#gems-option
    MESSAGE
  ]
)

Smoke.add_test("regex_directory_directive", {
  guid: 'test-guid',
  timestamp: :_,
  type: 'success',
  issues: [
    {
      message: "`Autumn#silver_week` performs a nil-check",
      links: ["https://github.com/troessner/reek/blob/v5.5.0/docs/Nil-Check.md"],
      id: "NilCheck",
      path: "app/models/seasons/test/summer.rb",
      location: { start_line: 8 },
      object: nil,
      git_blame_info: nil,
    }
  ],
  analyzer: { name: 'Reek', version: "5.5.0" }
})
