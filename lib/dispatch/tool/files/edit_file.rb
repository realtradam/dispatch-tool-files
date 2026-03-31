# frozen_string_literal: true

module Dispatch
  module Tool
    module Files
      EDIT_FILE = Dispatch::Tools::Definition.new(
        name: "edit_file",
        description: "Apply text edits to an existing file. Each edit replaces old_text with new_text sequentially.",
        parameters: {
          type: "object",
          properties: {
            path: {
              type: "string",
              description: "Path to the file to edit, relative to the worktree root."
            },
            edits: {
              type: "array",
              description: "Array of edit operations to apply sequentially.",
              items: {
                type: "object",
                properties: {
                  old_text: {
                    type: "string",
                    description: "The exact text to find in the file."
                  },
                  new_text: {
                    type: "string",
                    description: "The text to replace old_text with."
                  }
                },
                required: %w[old_text new_text],
                additionalProperties: false
              }
            }
          },
          required: %w[path edits],
          additionalProperties: false
        }
      ) do |params, context|
        worktree_path = context[:worktree_path]
        path = params[:path]
        edits = params[:edits]

        resolved = begin
          Sandbox.resolve_path(path, worktree_path:)
        rescue SandboxError => e
          next Dispatch::Tools::Result.failure(error: e.message)
        end

        unless File.exist?(resolved)
          next Dispatch::Tools::Result.failure(error: "File not found: #{path}")
        end

        content = File.read(resolved)
        edits_applied = 0
        error_result = nil

        edits.each do |edit|
          old_text = edit[:old_text] || edit["old_text"]
          new_text = edit[:new_text] || edit["new_text"]

          escaped = Regexp.new(Regexp.escape(old_text))
          occurrences = content.scan(escaped).length

          if occurrences.zero?
            error_result = Dispatch::Tools::Result.failure(
              error: "Edit #{edits_applied + 1}: old_text not found in #{path}"
            )
            break
          end

          if occurrences > 1
            error_result = Dispatch::Tools::Result.failure(
              error: "Edit #{edits_applied + 1}: ambiguous match — old_text found #{occurrences} times in #{path}. " \
                     "Provide more context to make the match unique."
            )
            break
          end

          content = content.sub(old_text, new_text)
          edits_applied += 1
        end

        next error_result if error_result

        File.write(resolved, content)
        Dispatch::Tools::Result.success(output: "Applied #{edits_applied} edit(s) to #{path}")
      end
    end
  end
end
