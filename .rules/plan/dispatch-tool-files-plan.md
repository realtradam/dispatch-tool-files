# Dispatch Tool Files — Gem Implementation Plan

This plan covers the full implementation of the `dispatch-tool-files` gem.

---

## Overview

This gem provides file operation tools for Subagents. All operations are sandboxed to the agent's worktree — no file access outside the worktree is permitted.

**Dependency:** `dispatch-tools-interface`

---

## Gem Structure

```
dispatch-tool-files/
├── lib/
│   └── dispatch/
│       └── tool/
│           └── files/
│               ├── read_file.rb
│               ├── write_file.rb
│               ├── edit_file.rb
│               ├── create_file.rb
│               ├── list_files.rb
│               ├── search_files.rb
│               ├── sandbox.rb
│               └── register.rb
├── spec/
│   └── dispatch/
│       └── tool/
│           └── files/
│               ├── read_file_spec.rb
│               ├── write_file_spec.rb
│               ├── edit_file_spec.rb
│               ├── create_file_spec.rb
│               ├── list_files_spec.rb
│               ├── search_files_spec.rb
│               └── sandbox_spec.rb
├── dispatch-tool-files.gemspec
├── Gemfile
├── Rakefile
└── README.md
```

---

## 1. Sandbox Module (`Dispatch::Tool::Files::Sandbox`)

All tools use this module to validate that file paths stay within the worktree.

### Methods

- `resolve_path(path, worktree_path:)` — Resolve a relative path against the worktree root. Expand symlinks, resolve `..`, and verify the resulting absolute path starts with `worktree_path`. Raises `Dispatch::Tool::Files::SandboxError` if the path escapes.
- `within_worktree?(path, worktree_path:)` — Boolean check.

### Security Considerations

- Must handle symlink attacks (symlink pointing outside worktree).
- Must handle `../` traversal.
- Must handle absolute paths (reject or re-root them).

---

## 2. Tools

Each tool is a `Dispatch::Tools::Definition` instance. All tools require `worktree_path` in the `context` hash.

### `read_file`

- **Parameters:** `path` (required, String), `start_line` (optional, Integer, 0-based), `end_line` (optional, Integer, 0-based, -1 for EOF).
- **Behavior:** Read file contents. If line range specified, return only those lines. Prefix each line with its line number.
- **Success output:** File contents as a string with line numbers.
- **Failure:** File not found, path outside sandbox, binary file detection.

### `write_file`

- **Parameters:** `path` (required, String), `content` (required, String).
- **Behavior:** Write/overwrite the entire file with the given content. Creates parent directories if needed.
- **Success output:** Confirmation message with path and byte count.
- **Failure:** Path outside sandbox, permission errors.

### `edit_file`

- **Parameters:** `path` (required, String), `edits` (required, Array of `{ old_text: String, new_text: String }`).
- **Behavior:** For each edit, find `old_text` in the file and replace with `new_text`. Edits are applied sequentially. If `old_text` is not found, the edit fails.
- **Success output:** Confirmation with number of edits applied.
- **Failure:** File not found, `old_text` not found, ambiguous match (multiple occurrences — require more context).

### `create_file`

- **Parameters:** `path` (required, String), `content` (required, String).
- **Behavior:** Create a new file. Fails if the file already exists (use `write_file` to overwrite). Creates parent directories.
- **Success output:** Confirmation message.
- **Failure:** File already exists, path outside sandbox.

### `list_files`

- **Parameters:** `path` (optional, String, defaults to `.`), `pattern` (optional, String, glob pattern), `recursive` (optional, Boolean, default `true`).
- **Behavior:** List files in the directory. Apply glob pattern if provided. Returns paths relative to the worktree root.
- **Success output:** Newline-separated list of file paths.
- **Failure:** Directory not found, path outside sandbox.

### `search_files`

- **Parameters:** `query` (required, String), `path` (optional, String, defaults to `.`), `pattern` (optional, String, file glob to filter), `is_regex` (optional, Boolean, default `false`).
- **Behavior:** Search for text in files. Returns matching lines with file paths and line numbers. Limit results to a reasonable maximum (e.g. 100 matches).
- **Success output:** Formatted search results.
- **Failure:** Invalid regex, path outside sandbox.

---

## 3. Registration (`Dispatch::Tool::Files.register(registry)`)

A convenience method that registers all file tools into a `Dispatch::Tools::Registry`.

```ruby
registry = Dispatch::Tools::Registry.new
Dispatch::Tool::Files.register(registry)
# Now registry contains: read_file, write_file, edit_file, create_file, list_files, search_files
```

---

## 4. Error Classes

- `Dispatch::Tool::Files::Error` — base error.
- `Dispatch::Tool::Files::SandboxError` — path escapes the worktree.
- `Dispatch::Tool::Files::FileNotFoundError` — file does not exist.
- `Dispatch::Tool::Files::FileExistsError` — file already exists (for create_file).

---

## 5. Testing

- **Sandbox tests:** Path resolution, traversal attacks, symlink attacks, absolute path rejection.
- **Per-tool tests:** Use a temporary directory as a fake worktree.
  - `read_file`: read full file, read line range, file not found, binary detection.
  - `write_file`: write new file, overwrite existing, create parent dirs.
  - `edit_file`: single edit, multiple edits, old_text not found, sequential application.
  - `create_file`: create new, fail on existing.
  - `list_files`: list all, glob filter, recursive/non-recursive.
  - `search_files`: plain text search, regex search, file pattern filter, result limiting.

---

## Key Constraints

- **All paths must be validated through the Sandbox** before any filesystem operation.
- Tools return `Dispatch::Tools::Result` (success or failure) — they never raise exceptions to the caller.
- The `context[:worktree_path]` is the absolute path to the worktree root, provided by the Rails agent loop.
- Binary file detection: `read_file` should detect and refuse to read binary files (check for null bytes in first N bytes).
