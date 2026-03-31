# frozen_string_literal: true

RSpec.describe "create_file tool" do
  let(:worktree_path) { Dir.mktmpdir("create-file-test") }
  let(:context) { { worktree_path: } }
  let(:registry) { Dispatch::Tools::Registry.new }

  before { Dispatch::Tool::Files.register(registry) }

  after { FileUtils.remove_entry(worktree_path) }

  subject(:tool) { registry.get("create_file") }

  describe "creating a new file" do
    it "creates a file with the given content" do
      result = tool.call({ "path" => "new_file.rb", "content" => "puts 'hello'" }, context:)

      expect(result.success?).to be true
      expect(File.read(File.join(worktree_path, "new_file.rb"))).to eq("puts 'hello'")
    end

    it "returns a confirmation message" do
      result = tool.call({ "path" => "created.txt", "content" => "content" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("created.txt")
    end

    it "creates parent directories as needed" do
      result = tool.call({ "path" => "deep/nested/dir/file.txt", "content" => "deep content" }, context:)

      expect(result.success?).to be true
      expect(File.read(File.join(worktree_path, "deep/nested/dir/file.txt"))).to eq("deep content")
    end
  end

  describe "error cases" do
    it "returns failure when the file already exists" do
      file_path = File.join(worktree_path, "existing.txt")
      File.write(file_path, "original")

      result = tool.call({ "path" => "existing.txt", "content" => "overwrite attempt" }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/already exists/i)
      expect(File.read(file_path)).to eq("original")
    end

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
