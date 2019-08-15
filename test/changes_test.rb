require_relative "test_helper"

class ChangesTest < Minitest::Test
  include TestHelper

  Changes = NodeHarness::Changes

  def test_changed_files
    mktmpdir do |base_path|
      mktmpdir do |head_path|
        mktmpdir do |working_path|
          base_path.join("unchanged.rb").write("hello world")
          head_path.join("unchanged.rb").write("hello world")
          working_path.join("unchanged.rb").write("hello world")

          base_path.join("changed1.rb").write("Hello World")
          head_path.join("changed1.rb").write("Open sesame")
          working_path.join("changed1.rb").write("Open sesame")

          head_path.join("changed2.rb").write("Review less, merge faster")
          working_path.join("changed2.rb").write("Review less, merge faster")

          working_path.join("built1.rb").write("Build apps with confidence")

          head_path.join("built2.rb").write("Built for developers")
          working_path.join("built2.rb").write("Healthy code ships faster.")

          base_path.join("ignored.rb").write("Read, write, and share stories that matter")
          head_path.join("ignored.rb").write("Reinventing teamwork")

          changes = Changes.calculate(base_dir: base_path, head_dir: head_path, working_dir: working_path)

          assert_equal [Pathname("changed1.rb"), Pathname("changed2.rb")], changes.changed_files.map(&:path)
          assert_equal [Pathname("unchanged.rb")], changes.unchanged_paths
          assert_equal [Pathname("built1.rb"), Pathname("built2.rb")], changes.untracked_paths
        end
      end
    end
  end

  def test_changed_files_with_empty_base
    # This is simulation for diff disabled mode, put everything to changed_files
    mktmpdir do |base_path|
      mktmpdir do |head_path|
        mktmpdir do |working_path|
          head_path.join("unchanged.rb").write("hello world")
          working_path.join("unchanged.rb").write("hello world")

          head_path.join("changed1.rb").write("Open sesame")
          working_path.join("changed1.rb").write("Open sesame")

          head_path.join("changed2.rb").write("Review less, merge faster")
          working_path.join("changed2.rb").write("Review less, merge faster")

          working_path.join("built1.rb").write("Build apps with confidence")

          head_path.join("built2.rb").write("Built for developers")
          working_path.join("built2.rb").write("Healthy code ships faster.")

          head_path.join("ignored.rb").write("Reinventing teamwork")

          changes = Changes.calculate(base_dir: base_path, head_dir: head_path, working_dir: working_path)

          assert_equal [Pathname("changed1.rb"), Pathname("changed2.rb"), Pathname("unchanged.rb")], changes.changed_files.map(&:path)
          assert_equal [], changes.unchanged_paths
          assert_equal [Pathname("built1.rb"), Pathname("built2.rb")], changes.untracked_paths
        end
      end
    end
  end

  def test_delete_unchanged
    mktmpdir do |dir|
      dir.join("file1").write("foo")
      dir.join("file2").write("foo")
      dir.join("file3").write("foo")

      changes = Changes.new(changed_files: [], unchanged_paths: [Pathname("file1"), Pathname("file2"), Pathname("file3")], untracked_paths: [])

      changes.delete_unchanged(dir: dir)

      refute dir.join("file1").file?
      refute dir.join("file2").file?
      refute dir.join("file3").file?
    end
  end

  def test_delete_unchanged_with_pattern
    mktmpdir do |dir|
      dir.join("file1").write("foo")
      dir.join("file2").write("foo")
      dir.join("file3").write("foo")

      changes = Changes.new(changed_files: [], unchanged_paths: [Pathname("file1"), Pathname("file2"), Pathname("file3")], untracked_paths: [])

      changes.delete_unchanged(dir: dir, only: ["file[2-3]"], except: ["file3"])

      assert dir.join("file1").file?
      refute dir.join("file2").file?
      assert dir.join("file3").file?
    end
  end

  def test_symlink
    mktmpdir do |base_path|
      mktmpdir do |head_path|
        mktmpdir do |working_path|
          working_path.join("dir").mkdir
          working_path.join("foo").write("bar")
          working_path.join("baz").make_symlink(Pathname("foo"))
          working_path.join("link").make_symlink(Pathname("../aaaaa"))

          changes = Changes.calculate(base_dir: base_path, head_dir: head_path, working_dir: working_path)

          assert changes.untracked_paths.include?(Pathname("foo"))
          assert changes.untracked_paths.include?(Pathname("baz"))
          refute changes.untracked_paths.include?(Pathname("link"))
        end
      end
    end
  end
end
