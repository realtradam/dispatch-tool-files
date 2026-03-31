# frozen_string_literal: true

RSpec.describe "edit_file tool" do
  let(:worktree_path) { Dir.mktmpdir("edit-file-test") }
  let(:context) { { worktree_path: } }
  let(:registry) { Dispatch::Tools::Registry.new }

  before { Dispatch::Tool::Files.register(registry) }

  after { FileUtils.remove_entry(worktree_path) }

  subject(:tool) { registry.get("edit_file") }

  describe "single edit" do
    it "replaces old_text with new_text in the file" do
      file_path = File.join(worktree_path, "code.rb")
      File.write(file_path, "def hello\n  puts 'hello'\nend\n")

      result = tool.call({
        "path" => "code.rb",
        "edits" => [{ "old_text" => "puts 'hello'", "new_text" => "puts 'goodbye'" }]
      }, context:)

      expect(result.success?).to be true
      expect(File.read(file_path)).to include("puts 'goodbye'")
      expect(File.read(file_path)).not_to include("puts 'hello'")
    end

    it "returns a confirmation with the number of edits applied" do
      file_path = File.join(worktree_path, "file.txt")
      File.write(file_path, "foo bar baz")

      result = tool.call({
        "path" => "file.txt",
        "edits" => [{ "old_text" => "bar", "new_text" => "qux" }]
      }, context:)

      expect(result.success?).to be true
      expect(result.output).to match(/1/i)
    end
  end

  describe "multiple edits" do
    it "applies multiple edits sequentially" do
      file_path = File.join(worktree_path, "multi.txt")
      File.write(file_path, "aaa bbb ccc")

      result = tool.call({
        "path" => "multi.txt",
        "edits" => [
          { "old_text" => "aaa", "new_text" => "xxx" },
          { "old_text" => "ccc", "new_text" => "zzz" }
        ]
      }, context:)

      expect(result.success?).to be true
      expect(File.read(file_path)).to eq("xxx bbb zzz")
    end

    it "applies edits sequentially so later edits see results of earlier ones" do
      file_path = File.join(worktree_path, "sequential.txt")
      File.write(file_path, "hello world")

      result = tool.call({
        "path" => "sequential.txt",
        "edits" => [
          { "old_text" => "hello", "new_text" => "hi" },
          { "old_text" => "hi world", "new_text" => "hi there" }
        ]
      }, context:)

      expect(result.success?).to be true
      expect(File.read(file_path)).to eq("hi there")
    end
  end

  describe "error cases" do
    it "returns failure when old_text is not found in the file" do
      file_path = File.join(worktree_path, "missing.txt")
      File.write(file_path, "actual content")

      result = tool.call({
        "path" => "missing.txt",
        "edits" => [{ "old_text" => "nonexistent text", "new_text" => "replacement" }]
      }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/not found/i)
    end

    it "returns failure when the file does not exist" do
      result = tool.call({
        "path" => "ghost.txt",
        "edits" => [{ "old_text" => "a", "new_text" => "b" }]
      }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/not found|does not exist/i)
    end

    it "returns failure when the path escapes the sandbox" do
      result = tool.call({
        "path" => "../../../etc/passwd",
        "edits" => [{ "old_text" => "root", "new_text" => "hacked" }]
      }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/sandbox|outside/i)
    end

    it "returns failure when old_text matches ambiguously (multiple occurrences)" do
      file_path = File.join(worktree_path, "ambiguous.txt")
      File.write(file_path, "foo bar foo baz foo")

      result = tool.call({
        "path" => "ambiguous.txt",
        "edits" => [{ "old_text" => "foo", "new_text" => "qux" }]
      }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/ambiguous|multiple/i)
    end
  end

  describe "parameter validation" do
    it "requires the path parameter" do
      result = tool.call({
        "edits" => [{ "old_text" => "a", "new_text" => "b" }]
      }, context:)

      expect(result.failure?).to be true
    end

    it "requires the edits parameter" do
      File.write(File.join(worktree_path, "file.txt"), "content")

      result = tool.call({ "path" => "file.txt" }, context:)

      expect(result.failure?).to be true
    end
  end
end
