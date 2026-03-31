# frozen_string_literal: true

module Dispatch
  module Tool
    module Files
      LIST_FILES = Dispatch::Tools::Definition.new(
        name: "list_files",
        description: "List files in a directory. Returns paths relative to the worktree root.",
        parameters: {
          type: "object",
          properties: {
            path: {
              type: "string",
              description: "Directory path relative to the worktree root. Defaults to the root."
            },
            pattern: {
              type: "string",
              description: "Glob pattern to filter files (e.g. '**/*.rb')."
            },
            recursive: {
              type: "boolean",
              description: "Whether to list files recursively. Defaults to true."
            }
          },
          additionalProperties: false
        }
      ) do |params, context|
        worktree_path = context[:worktree_path]
        path = params.fetch(:path, ".")
        pattern = params[:pattern]
        recursive = params.fetch(:recursive, true)

        resolved = begin
          Sandbox.resolve_path(path, worktree_path:)
        rescue SandboxError => e
          next Dispatch::Tools::Result.failure(error: e.message)
        end

        unless File.directory?(resolved)
          next Dispatch::Tools::Result.failure(error: "Directory not found: #{path}")
        end

        glob = if pattern
                 File.join(resolved, pattern)
               elsif recursive
                 File.join(resolved, "**", "*")
               else
                 File.join(resolved, "*")
               end

        entries = Dir.glob(glob).select { |f| File.file?(f) }

        worktree_real = File.realpath(worktree_path)
        relative_paths = entries.map { |f| f.delete_prefix("#{worktree_real}/") }.sort

        Dispatch::Tools::Result.success(output: relative_paths.join("\n"))
      end
    end
  end
end
