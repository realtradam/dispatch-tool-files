# frozen_string_literal: true

RSpec.describe "list_files tool" do
  let(:worktree_path) { Dir.mktmpdir("list-files-test") }
  let(:context) { { worktree_path: } }
  let(:registry) { Dispatch::Tools::Registry.new }

  before { Dispatch::Tool::Files.register(registry) }

  after { FileUtils.remove_entry(worktree_path) }

  subject(:tool) { registry.get("list_files") }

  describe "listing all files" do
    before do
      FileUtils.mkdir_p(File.join(worktree_path, "src", "lib"))
      File.write(File.join(worktree_path, "README.md"), "readme")
      File.write(File.join(worktree_path, "src", "main.rb"), "main")
      File.write(File.join(worktree_path, "src", "lib", "helper.rb"), "helper")
    end

    it "lists all files recursively by default" do
      result = tool.call({}, context:)

      expect(result.success?).to be true
      expect(result.output).to include("README.md")
      expect(result.output).to include("src/main.rb")
      expect(result.output).to include("src/lib/helper.rb")
    end

    it "returns paths relative to the worktree root" do
      result = tool.call({}, context:)

      expect(result.success?).to be true
      expect(result.output).not_to include(worktree_path)
    end
  end

  describe "listing with a path" do
    before do
      FileUtils.mkdir_p(File.join(worktree_path, "src"))
      FileUtils.mkdir_p(File.join(worktree_path, "test"))
      File.write(File.join(worktree_path, "src", "app.rb"), "app")
      File.write(File.join(worktree_path, "test", "app_test.rb"), "test")
    end

    it "lists files only in the specified subdirectory" do
      result = tool.call({ "path" => "src" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("app.rb")
      expect(result.output).not_to include("app_test.rb")
    end
  end

  describe "glob pattern filtering" do
    before do
      FileUtils.mkdir_p(File.join(worktree_path, "src"))
      File.write(File.join(worktree_path, "src", "main.rb"), "main")
      File.write(File.join(worktree_path, "src", "style.css"), "css")
      File.write(File.join(worktree_path, "README.md"), "readme")
    end

    it "filters files using a glob pattern" do
      result = tool.call({ "pattern" => "**/*.rb" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("main.rb")
      expect(result.output).not_to include("style.css")
      expect(result.output).not_to include("README.md")
    end

    it "supports multiple extension glob patterns" do
      result = tool.call({ "pattern" => "**/*.{rb,md}" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("main.rb")
      expect(result.output).to include("README.md")
      expect(result.output).not_to include("style.css")
    end
  end

  describe "recursive vs non-recursive" do
    before do
      FileUtils.mkdir_p(File.join(worktree_path, "nested", "deep"))
      File.write(File.join(worktree_path, "top.txt"), "top")
      File.write(File.join(worktree_path, "nested", "mid.txt"), "mid")
      File.write(File.join(worktree_path, "nested", "deep", "bottom.txt"), "bottom")
    end

    it "includes nested files when recursive is true" do
      result = tool.call({ "recursive" => true }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("top.txt")
      expect(result.output).to include("nested/mid.txt")
      expect(result.output).to include("nested/deep/bottom.txt")
    end

    it "lists only top-level files when recursive is false" do
      result = tool.call({ "recursive" => false }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("top.txt")
      expect(result.output).not_to include("mid.txt")
      expect(result.output).not_to include("bottom.txt")
    end
  end

  describe "error cases" do
    it "returns failure when the directory does not exist" do
      result = tool.call({ "path" => "nonexistent_dir" }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/not found|does not exist/i)
    end

    it "returns failure when the path escapes the sandbox" do
      result = tool.call({ "path" => "../../../etc" }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/sandbox|outside/i)
    end
  end
end
