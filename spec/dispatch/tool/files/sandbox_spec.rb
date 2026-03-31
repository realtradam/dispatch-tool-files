# frozen_string_literal: true

RSpec.describe Dispatch::Tool::Files::Sandbox do
  let(:worktree_path) { Dir.mktmpdir("sandbox-test") }

  after { FileUtils.remove_entry(worktree_path) }

  describe ".resolve_path" do
    it "resolves a simple relative path within the worktree" do
      file_path = File.join(worktree_path, "hello.txt")
      FileUtils.touch(file_path)

      resolved = described_class.resolve_path("hello.txt", worktree_path:)

      expect(resolved).to eq(file_path)
    end

    it "resolves a nested relative path within the worktree" do
      nested_dir = File.join(worktree_path, "src", "lib")
      FileUtils.mkdir_p(nested_dir)
      file_path = File.join(nested_dir, "main.rb")
      FileUtils.touch(file_path)

      resolved = described_class.resolve_path("src/lib/main.rb", worktree_path:)

      expect(resolved).to eq(file_path)
    end

    it "resolves paths with . components" do
      file_path = File.join(worktree_path, "hello.txt")
      FileUtils.touch(file_path)

      resolved = described_class.resolve_path("./hello.txt", worktree_path:)

      expect(resolved).to eq(file_path)
    end

    it "raises SandboxError for .. traversal escaping the worktree" do
      expect do
        described_class.resolve_path("../../../etc/passwd", worktree_path:)
      end.to raise_error(Dispatch::Tool::Files::SandboxError)
    end

    it "raises SandboxError for deeply nested .. traversal that escapes" do
      FileUtils.mkdir_p(File.join(worktree_path, "a", "b"))

      expect do
        described_class.resolve_path("a/b/../../../../etc/passwd", worktree_path:)
      end.to raise_error(Dispatch::Tool::Files::SandboxError)
    end

    it "allows .. traversal that stays within the worktree" do
      FileUtils.mkdir_p(File.join(worktree_path, "a", "b"))
      file_path = File.join(worktree_path, "a", "file.txt")
      FileUtils.touch(file_path)

      resolved = described_class.resolve_path("a/b/../file.txt", worktree_path:)

      expect(resolved).to eq(file_path)
    end

    it "raises SandboxError for absolute paths outside the worktree" do
      expect do
        described_class.resolve_path("/etc/passwd", worktree_path:)
      end.to raise_error(Dispatch::Tool::Files::SandboxError)
    end

    it "raises SandboxError for absolute paths that happen to share a prefix" do
      expect do
        described_class.resolve_path("#{worktree_path}-evil/secret.txt", worktree_path:)
      end.to raise_error(Dispatch::Tool::Files::SandboxError)
    end

    it "raises SandboxError for symlinks pointing outside the worktree" do
      link_path = File.join(worktree_path, "evil_link")
      File.symlink("/etc/passwd", link_path)

      expect do
        described_class.resolve_path("evil_link", worktree_path:)
      end.to raise_error(Dispatch::Tool::Files::SandboxError)
    end

    it "raises SandboxError for symlinked directories pointing outside the worktree" do
      link_path = File.join(worktree_path, "evil_dir")
      File.symlink("/tmp", link_path)

      expect do
        described_class.resolve_path("evil_dir/some_file.txt", worktree_path:)
      end.to raise_error(Dispatch::Tool::Files::SandboxError)
    end

    it "allows symlinks that resolve within the worktree" do
      target_path = File.join(worktree_path, "real.txt")
      FileUtils.touch(target_path)

      link_path = File.join(worktree_path, "link.txt")
      File.symlink(target_path, link_path)

      resolved = described_class.resolve_path("link.txt", worktree_path:)

      expect(resolved).to eq(target_path)
    end

    it "resolves the worktree path itself for an empty string" do
      resolved = described_class.resolve_path("", worktree_path:)

      expect(resolved).to eq(worktree_path)
    end

    it "resolves the worktree path for ." do
      resolved = described_class.resolve_path(".", worktree_path:)

      expect(resolved).to eq(worktree_path)
    end

    it "handles paths to non-existent files within the worktree" do
      resolved = described_class.resolve_path("nonexistent.txt", worktree_path:)

      expect(resolved).to eq(File.join(worktree_path, "nonexistent.txt"))
    end

    it "handles paths to non-existent nested directories within the worktree" do
      resolved = described_class.resolve_path("a/b/c/file.txt", worktree_path:)

      expect(resolved).to eq(File.join(worktree_path, "a/b/c/file.txt"))
    end
  end

  describe ".within_worktree?" do
    it "returns true for a path inside the worktree" do
      FileUtils.touch(File.join(worktree_path, "file.txt"))

      expect(described_class.within_worktree?("file.txt", worktree_path:)).to be true
    end

    it "returns false for a path escaping the worktree" do
      expect(described_class.within_worktree?("../../etc/passwd", worktree_path:)).to be false
    end

    it "returns false for an absolute path outside the worktree" do
      expect(described_class.within_worktree?("/etc/passwd", worktree_path:)).to be false
    end

    it "returns false for a symlink pointing outside the worktree" do
      link_path = File.join(worktree_path, "evil_link")
      File.symlink("/etc/passwd", link_path)

      expect(described_class.within_worktree?("evil_link", worktree_path:)).to be false
    end

    it "returns true for a symlink that stays inside the worktree" do
      target = File.join(worktree_path, "real.txt")
      FileUtils.touch(target)
      File.symlink(target, File.join(worktree_path, "link.txt"))

      expect(described_class.within_worktree?("link.txt", worktree_path:)).to be true
    end

    it "returns true for non-existent paths within the worktree" do
      expect(described_class.within_worktree?("does/not/exist.txt", worktree_path:)).to be true
    end
  end
end
