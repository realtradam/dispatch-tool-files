# frozen_string_literal: true

module Dispatch
  module Tool
    module Files
      WRITE_FILE = Dispatch::Tools::Definition.new(
        name: "write_file",
        description: "Write or overwrite a file with the given content. Creates parent directories if needed.",
        parameters: {
          type: "object",
          properties: {
            path: {
              type: "string",
              description: "Path to the file to write, relative to the worktree root."
            },
            content: {
              type: "string",
              description: "The content to write to the file."
            }
          },
          required: %w[path content],
          additionalProperties: false
        }
      ) do |params, context|
        worktree_path = context[:worktree_path]
        path = params[:path]
        content = params[:content]

        resolved = begin
          Sandbox.resolve_path(path, worktree_path:)
        rescue SandboxError => e
          next Dispatch::Tools::Result.failure(error: e.message)
        end

        FileUtils.mkdir_p(File.dirname(resolved))
        File.write(resolved, content)

        byte_count = content.bytesize
        Dispatch::Tools::Result.success(output: "Wrote #{byte_count} bytes to #{path}")
      end
    end
  end
end
