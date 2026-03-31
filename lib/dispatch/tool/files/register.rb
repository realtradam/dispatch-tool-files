# frozen_string_literal: true

module Dispatch
  module Tool
    module Files
      TOOLS = [
        READ_FILE,
        WRITE_FILE,
        EDIT_FILE,
        CREATE_FILE,
        LIST_FILES,
        SEARCH_FILES
      ].freeze

      def self.register(registry)
        TOOLS.each { |tool| registry.register(tool) }
        registry
      end
    end
  end
end
