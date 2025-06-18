# frozen_string_literal: true

module RubyLLM
  # Represents a function call from an AI model to a Tool.
  # Encapsulates the function name, arguments, and execution results
  # in a clean Ruby interface.
  #
  # Example:
  #   tool_call = ToolCall.new(
  #     id: "call_123",
  #     name: "calculator",
  #     arguments: { expression: "2 + 2" }
  #   )
  class ToolCall
    attr_reader :id, :name, :arguments

    def initialize(id:, name:, arguments: {})
      @id = id
      @name = name
      @arguments = arguments
    end

    def to_h
      {
        id: @id,
        name: @name,
        arguments: @arguments
      }
    end
  end
end
