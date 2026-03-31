# frozen_string_literal: true

RSpec.describe "search_files tool" do
  let(:worktree_path) { Dir.mktmpdir("search-files-test") }
  let(:context) { { worktree_path: } }
  let(:registry) { Dispatch::Tools::Registry.new }

  before { Dispatch::Tool::Files.register(registry) }

  after { FileUtils.remove_entry(worktree_path) }

  subject(:tool) { registry.get("search_files") }

  describe "plain text search" do
    before do
      FileUtils.mkdir_p(File.join(worktree_path, "src"))
      File.write(File.join(worktree_path, "src", "app.rb"), "def hello\n  puts 'hello world'\nend\n")
      File.write(File.join(worktree_path, "src", "utils.rb"), "def goodbye\n  puts 'goodbye world'\nend\n")
      File.write(File.join(worktree_path, "README.md"), "# Hello World\n\nA sample project.\n")
    end

    it "finds matches across multiple files" do
      result = tool.call({ "query" => "world" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("hello world")
      expect(result.output).to include("goodbye world")
    end

    it "includes file paths in the results" do
      result = tool.call({ "query" => "hello" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("src/app.rb")
    end

    it "includes line numbers in the results" do
      result = tool.call({ "query" => "puts" }, context:)

      expect(result.success?).to be true
      # line numbers should appear in the output
      expect(result.output).to match(/\d+/)
    end
  end

  describe "regex search" do
    before do
      File.write(File.join(worktree_path, "data.txt"), "foo123bar\nbaz456qux\nhello789\n")
    end

    it "finds matches using a regular expression" do
      result = tool.call({ "query" => "\\d{3}", "is_regex" => true }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("foo123bar")
      expect(result.output).to include("baz456qux")
      expect(result.output).to include("hello789")
    end

    it "returns failure for an invalid regex" do
      result = tool.call({ "query" => "[unclosed", "is_regex" => true }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/invalid|regex|regexp/i)
    end
  end

  describe "scoped search with path" do
    before do
      FileUtils.mkdir_p(File.join(worktree_path, "src"))
      FileUtils.mkdir_p(File.join(worktree_path, "test"))
      File.write(File.join(worktree_path, "src", "main.rb"), "target line\n")
      File.write(File.join(worktree_path, "test", "main_test.rb"), "target line\n")
    end

    it "searches only within the specified path" do
      result = tool.call({ "query" => "target", "path" => "src" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("src/main.rb")
      expect(result.output).not_to include("test/main_test.rb")
    end
  end

  describe "file pattern filtering" do
    before do
      FileUtils.mkdir_p(File.join(worktree_path, "src"))
      File.write(File.join(worktree_path, "src", "app.rb"), "target\n")
      File.write(File.join(worktree_path, "src", "style.css"), "target\n")
    end

    it "filters search results by file glob pattern" do
      result = tool.call({ "query" => "target", "pattern" => "**/*.rb" }, context:)

      expect(result.success?).to be true
      expect(result.output).to include("app.rb")
      expect(result.output).not_to include("style.css")
    end
  end

  describe "result limiting" do
    before do
      content = (1..200).map { |i| "match_target line #{i}" }.join("\n") + "\n"
      File.write(File.join(worktree_path, "big_file.txt"), content)
    end

    it "limits results to a reasonable maximum" do
      result = tool.call({ "query" => "match_target" }, context:)

      expect(result.success?).to be true
      match_count = result.output.scan(/match_target/).size
      expect(match_count).to be <= 100
    end
  end

  describe "error cases" do
    it "returns failure when the path escapes the sandbox" do
      result = tool.call({ "query" => "root", "path" => "../../../etc" }, context:)

      expect(result.failure?).to be true
      expect(result.error).to match(/sandbox|outside/i)
    end
  end

  describe "parameter validation" do
    it "requires the query parameter" do
      result = tool.call({}, context:)

      expect(result.failure?).to be true
    end
  end
end
