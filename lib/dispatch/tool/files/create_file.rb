# frozen_string_literal: true

module Dispatch
  module Tool
    module Files
      CREATE_FILE = Dispatch::Tools::Definition.new(
        name: "create_file",
        description: "Create a new file with the given content. Fails if the file already exists.",
        parameters: {
          type: "object",
          properties: {
            path: {
              type: "string",
              description: "Path to the file to create, relative to the worktree root."
            },
            content: {
              type: "string",
              description: "The content to write to the new file."
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

        if File.exist?(resolved)
          next Dispatch::Tools::Result.failure(error: "File already exists: #{path}. Use write_file to overwrite.")
        end

        FileUtils.mkdir_p(File.dirname(resolved))
        File.write(resolved, content)

        Dispatch::Tools::Result.success(output: "Created #{path}")
      end
    end
  end
end
