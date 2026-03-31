# frozen_string_literal: true

module Dispatch
  module Tool
    module Files
      module Sandbox
        module_function

        def resolve_path(path, worktree_path:)
          worktree_real = File.realpath(worktree_path)

          # Join the path against the worktree root
          joined = File.expand_path(path, worktree_real)

          # Check the expanded (logical) path first — catches ../traversal and absolute paths
          unless joined.start_with?("#{worktree_real}/") || joined == worktree_real
            raise SandboxError, "Path '#{path}' resolves outside the worktree sandbox"
          end

          # For existing paths, resolve symlinks and verify the real path
          if File.exist?(joined)
            real = File.realpath(joined)

            unless real.start_with?("#{worktree_real}/") || real == worktree_real
              raise SandboxError, "Path '#{path}' resolves outside the worktree sandbox (symlink escape)"
            end

            real
          else
            # For non-existent paths, resolve as much of the existing prefix as possible
            # to catch symlinked directory components pointing outside the worktree
            parts = joined.delete_prefix("#{worktree_real}/").split("/")
            current = worktree_real

            parts.each_with_index do |part, i|
              candidate = File.join(current, part)

              if File.symlink?(candidate)
                real_target = File.realpath(candidate)

                unless real_target.start_with?("#{worktree_real}/") || real_target == worktree_real
                  raise SandboxError, "Path '#{path}' resolves outside the worktree sandbox (symlink escape)"
                end

                current = real_target
              elsif File.exist?(candidate)
                current = File.realpath(candidate)
              else
                # Remainder of the path doesn't exist on disk — that's fine, return the logical path
                remaining = parts[(i + 1)..]

                return remaining.empty? ? candidate : File.join(candidate, *remaining)
              end
            end

            current
          end
        end

        def within_worktree?(path, worktree_path:)
          resolve_path(path, worktree_path:)
          true
        rescue SandboxError
          false
        end
      end
    end
  end
end
