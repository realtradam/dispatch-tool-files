# frozen_string_literal: true

module Dispatch
  module Tool
    module Files
      SEARCH_FILES = Dispatch::Tools::Definition.new(
        name: "search_files",
        description: "Search for text in files. Returns matching lines with file paths and line numbers.",
        parameters: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "The text or regex pattern to search for."
            },
            path: {
              type: "string",
              description: "Directory to search within, relative to the worktree root. Defaults to root."
            },
            pattern: {
              type: "string",
              description: "Glob pattern to filter which files to search (e.g. '**/*.rb')."
            },
            is_regex: {
              type: "boolean",
              description: "Whether the query is a regular expression. Defaults to false."
            }
          },
          required: %w[query],
          additionalProperties: false
        }
      ) do |params, context|
        worktree_path = context[:worktree_path]
        query = params[:query]
        path = params.fetch(:path, ".")
        file_pattern = params[:pattern]
        is_regex = params.fetch(:is_regex, false)

        resolved = begin
          Sandbox.resolve_path(path, worktree_path:)
        rescue SandboxError => e
          next Dispatch::Tools::Result.failure(error: e.message)
        end

        regex = if is_regex
                  begin
                    Regexp.new(query)
                  rescue RegexpError => e
                    next Dispatch::Tools::Result.failure(error: "Invalid regex: #{e.message}")
                  end
                else
                  Regexp.new(Regexp.escape(query))
                end

        # Build file list
        glob = if file_pattern
                 File.join(resolved, file_pattern)
               else
                 File.join(resolved, "**", "*")
               end

        files = Dir.glob(glob).select { |f| File.file?(f) }.sort

        worktree_real = File.realpath(worktree_path)
        max_results = 100
        matches = []

        files.each do |file_path|
          # Skip binary files
          sample = File.binread(file_path, 8192)
          next if sample&.include?("\x00")

          relative = file_path.delete_prefix("#{worktree_real}/")

          File.readlines(file_path).each_with_index do |line, idx|
            if regex.match?(line)
              matches << "#{relative}:#{idx + 1}: #{line.chomp}"
              break if matches.length >= max_results
            end
          end

          break if matches.length >= max_results
        end

        Dispatch::Tools::Result.success(output: matches.join("\n"))
      end
    end
  end
end
