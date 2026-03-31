# frozen_string_literal: true

RSpec.describe "read_file tool" do
  let(:worktree_path) { Dir.mktmpdir("read-file-test") }
  let(:context) { { worktree_path: } }
  let(:registry) { Dispatch::Tools::Registry.new }

  before { Dispatch::Tool::Files.register(registry) }

  after { FileUtils.remove_entry(worktree_path) }

  subject(:tool) { registry.get("read_file") }

  describe "reading a full file" do
    it "returns file contents with line numbers" do
      File.write(File.join(worktree_path, "hello.txt"), "line one\nline two\nline three\n")

      result = tool.call({ "path" => "hello.txt" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("line one")
      expect(result.output).to include("line two")
      expect(result.output).to include("line three")
    end

    it "prefixes each line with its line number" do
      File.write(File.join(worktree_path, "numbered.txt"), "alpha\nbeta\ngamma\n")

      result = tool.call({ "path" => "numbered.txt" }, context:)

      expect(result.success?).to be true
      lines = result.output.split("\n")
      expect(lines[0]).to match(/\A\s*0.*alpha/)
      expect(lines[1]).to match(/\A\s*1.*beta/)
      expect(lines[2]).to match(/\A\s*2.*gamma/)
    end
  end

  describe "reading a line range" do
    before do
      content = (0..9).map { |i| "line #{i}" }.join("\n") + "\n"
      File.write(File.join(worktree_path, "lines.txt"), content)
    end

    it "returns only the specified line range (0-based)" do
      result = tool.call({ "path" => "lines.txt", "start_line" => 2, "end_line" => 4 }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("line 2")
      expect(result.output).to include("line 3")
      expect(result.output).to include("line 4")
      expect(result.output).not_to include("line 1")
      expect(result.output).not_to include("line 5")
    end

    it "reads from start_line to end of file when end_line is -1" do
      result = tool.call({ "path" => "lines.txt", "start_line" => 8, "end_line" => -1 }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("line 8")
      expect(result.output).to include("line 9")
      expect(result.output).not_to include("line 7")
    end

    it "reads from the beginning when only end_line is specified" do
      result = tool.call({ "path" => "lines.txt", "end_line" => 1 }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("line 0")
      expect(result.output).to include("line 1")
      expect(result.output).not_to include("line 2")
    end
  end

  describe "error cases" do
    it "returns failure when the file does not exist" do
      result = tool.call({ "path" => "nonexistent.txt" }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/not found|does not exist/i)
    end

    it "returns failure when the path escapes the sandbox" do
      result = tool.call({ "path" => "../../../etc/passwd" }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/sandbox|outside/i)
    end

    it "returns failure for a binary file" do
      binary_path = File.join(worktree_path, "binary.bin")
      File.write(binary_path, "Hello\x00World\x00Binary\x00Content")

      result = tool.call({ "path" => "binary.bin" }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/binary/i)
    end
  end

  describe "parameter validation" do
    it "requires the path parameter" do
      result = tool.call({}, context:)

      expect(result.failure?).to be true
    end
  end
end
