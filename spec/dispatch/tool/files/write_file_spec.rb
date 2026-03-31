# frozen_string_literal: true

RSpec.describe "write_file tool" do
  let(:worktree_path) { Dir.mktmpdir("write-file-test") }
  let(:context) { { worktree_path: } }
  let(:registry) { Dispatch::Tools::Registry.new }

  before { Dispatch::Tool::Files.register(registry) }

  after { FileUtils.remove_entry(worktree_path) }

  subject(:tool) { registry.get("write_file") }

  describe "writing a new file" do
    it "creates a new file with the given content" do
      result = tool.call({ "path" => "new_file.txt", "content" => "Hello, World!" }, context:)

      expect(result.success?).to be true
      expect(File.read(File.join(worktree_path, "new_file.txt"))).to eq("Hello, World!")
    end

    it "returns a confirmation message with path and byte count" do
      result = tool.call({ "path" => "output.txt", "content" => "12345" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("output.txt")
      expect(result.output).to match(/5\b.*bytes?/i)
    end
  end

  describe "overwriting an existing file" do
    it "replaces the entire content of an existing file" do
      file_path = File.join(worktree_path, "existing.txt")
      File.write(file_path, "old content")

      result = tool.call({ "path" => "existing.txt", "content" => "new content" }, context:)

      expect(result.success?).to be true
      expect(File.read(file_path)).to eq("new content")
    end
  end

  describe "creating parent directories" do
    it "creates intermediate directories as needed" do
      result = tool.call({ "path" => "a/b/c/deep.txt", "content" => "deep" }, context:)

      expect(result.success?).to be true
      expect(File.read(File.join(worktree_path, "a/b/c/deep.txt"))).to eq("deep")
    end
  end

  describe "error cases" do
    it "returns failure when the path escapes the sandbox" do
      result = tool.call({ "path" => "../../../tmp/evil.txt", "content" => "bad" }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/sandbox|outside/i)
    end
  end

  describe "parameter validation" do
    it "requires the path parameter" do
      result = tool.call({ "content" => "data" }, context:)

      expect(result.failure?).to be true
    end

    it "requires the content parameter" do
      result = tool.call({ "path" => "file.txt" }, context:)

      expect(result.failure?).to be true
    end
  end
end
