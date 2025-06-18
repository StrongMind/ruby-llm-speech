# frozen_string_literal: true

module RubyLLMSpeech
  class ConversationTranscript
    attr_reader :session_id, :messages, :started_at, :metadata

    def initialize(session_id:, metadata: {})
      @session_id = session_id
      @messages = []
      @started_at = Time.now
      @metadata = metadata
    end

    def add_message(role:, content:, type: :text, timestamp: nil, metadata: {})
      message = TranscriptMessage.new(
        role: role,
        content: content,
        type: type,
        timestamp: timestamp || Time.now,
        metadata: metadata
      )
      
      @messages << message
      message
    end

    def add_user_speech(content, metadata = {})
      add_message(
        role: :user,
        content: content,
        type: :speech,
        metadata: metadata.merge(input_type: "audio")
      )
    end

    def add_assistant_speech(content, metadata = {})
      add_message(
        role: :assistant,
        content: content,
        type: :speech,
        metadata: metadata.merge(output_type: "audio")
      )
    end

    def add_system_message(content, metadata = {})
      add_message(
        role: :system,
        content: content,
        type: :system,
        metadata: metadata
      )
    end

    def add_tool_call(tool_name, method_name, arguments, result, metadata: {})
      add_message(
        role: :tool,
        content: "#{tool_name}.#{method_name}(#{arguments.inspect}) -> #{result.inspect}",
        type: :tool_execution,
        metadata: metadata.merge(
          tool_name: tool_name,
          method_name: method_name,
          arguments: arguments,
          result: result
        )
      )
    end

    def add_error(error_message, metadata = {})
      add_message(
        role: :system,
        content: "Error: #{error_message}",
        type: :error,
        metadata: metadata.merge(error: true)
      )
    end

    def get_messages(role: nil, type: nil, since: nil)
      filtered_messages = @messages.dup

      filtered_messages = filtered_messages.select { |msg| msg.role == role } if role
      filtered_messages = filtered_messages.select { |msg| msg.type == type } if type
      filtered_messages = filtered_messages.select { |msg| msg.timestamp >= since } if since

      filtered_messages
    end

    def get_conversation_summary
      user_messages = get_messages(role: :user)
      assistant_messages = get_messages(role: :assistant)
      tool_calls = get_messages(type: :tool_execution)

      {
        session_id: @session_id,
        started_at: @started_at,
        duration: Time.now - @started_at,
        total_messages: @messages.length,
        user_messages: user_messages.length,
        assistant_messages: assistant_messages.length,
        tool_calls: tool_calls.length,
        last_activity: @messages.last&.timestamp
      }
    end

    def to_text(include_metadata: false, include_timestamps: true)
      @messages.map do |message|
        parts = []
        
        if include_timestamps
          parts << "[#{message.timestamp.strftime('%H:%M:%S')}]"
        end
        
        parts << "#{message.role.to_s.upcase}:"
        parts << message.content
        
        if include_metadata && message.metadata.any?
          parts << "(#{message.metadata.inspect})"
        end
        
        parts.join(" ")
      end.join("\n")
    end

    def to_hash
      {
        session_id: @session_id,
        started_at: @started_at,
        metadata: @metadata,
        messages: @messages.map(&:to_hash)
      }
    end

    def export_to_file(filename, format: :text)
      content = case format
                when :text
                  to_text
                when :json
                  JSON.pretty_generate(to_hash)
                else
                  raise ArgumentError, "Unsupported format: #{format}"
                end

      File.write(filename, content)
    end

    def clear!
      @messages.clear
      @started_at = Time.now
    end

    def message_count
      @messages.length
    end

    def empty?
      @messages.empty?
    end
  end

  class TranscriptMessage
    attr_reader :role, :content, :type, :timestamp, :metadata

    def initialize(role:, content:, type: :text, timestamp: nil, metadata: {})
      @role = role.to_sym
      @content = content
      @type = type.to_sym
      @timestamp = timestamp || Time.now
      @metadata = metadata
    end

    def to_hash
      {
        role: @role,
        content: @content,
        type: @type,
        timestamp: @timestamp,
        metadata: @metadata
      }
    end

    def to_s
      "#{@role}: #{@content}"
    end
  end
end