# frozen_string_literal: true

require "dispatch/tools/interface"
require "fileutils"
require_relative "files/version"

module Dispatch
  module Tool
    module Files
      class Error < StandardError; end
      class SandboxError < Error; end
      class FileNotFoundError < Error; end
      class FileExistsError < Error; end
    end
  end
end

require_relative "files/sandbox"
require_relative "files/read_file"
require_relative "files/write_file"
require_relative "files/edit_file"
require_relative "files/create_file"
require_relative "files/list_files"
require_relative "files/search_files"
require_relative "files/register"
