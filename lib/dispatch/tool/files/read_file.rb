# frozen_string_literal: true

module Dispatch
  module Tool
    module Files
      READ_FILE = Dispatch::Tools::Definition.new(
        name: "read_file",
        description: "Read the contents of a file. Returns file contents with line numbers.",
        parameters: {
          type: "object",
          properties: {
            path: {
              type: "string",
              description: "Path to the file to read, relative to the worktree root."
            },
            start_line: {
              type: "integer",
              description: "The line number to start reading from (0-based). Defaults to 0."
            },
            end_line: {
              type: "integer",
              description: "The inclusive line number to stop reading at (0-based). Use -1 for end of file."
            }
          },
          required: %w[path],
          additionalProperties: false
        }
      ) do |params, context|
        worktree_path = context[:worktree_path]
        path = params[:path]

        resolved = begin
          Sandbox.resolve_path(path, worktree_path:)
        rescue SandboxError => e
          next Dispatch::Tools::Result.failure(error: e.message)
        end

        unless File.exist?(resolved)
          next Dispatch::Tools::Result.failure(error: "File not found: #{path}")
        end

        # Binary file detection: check first 8192 bytes for null bytes
        sample = File.binread(resolved, 8192)
        if sample.include?("\x00")
          next Dispatch::Tools::Result.failure(error: "Cannot read binary file: #{path}")
        end

        lines = File.readlines(resolved)

        start_line = params.fetch(:start_line, 0)
        end_line = params.fetch(:end_line, -1)
        end_line = lines.length - 1 if end_line == -1

        selected = lines[start_line..end_line] || []

        # Calculate padding width based on the highest line number
        width = end_line.to_s.length

        output = selected.each_with_index.map do |line, idx|
          line_num = start_line + idx
          "#{line_num.to_s.rjust(width)}: #{line}"
        end.join

        Dispatch::Tools::Result.success(output:)
      end
    end
  end
end
