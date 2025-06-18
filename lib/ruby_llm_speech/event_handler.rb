# frozen_string_literal: true

module RubyLLMSpeech
  # Handles events from Nova Sonic, manages conversation state, and supports barge-in functionality
  class EventHandler
    attr_reader :conversation_state, :current_role, :is_speaking, :can_interrupt

    # Initialize event handler
    def initialize
      @conversation_state = :idle
      @current_role = nil
      @is_speaking = false
      @can_interrupt = true
      @text_buffer = ""
      @audio_buffer = []
      @event_callbacks = {}
      @tools = {}
    end

    # Register callback for specific event type
    #
    # @param event_type [Symbol] Event type to listen for
    # @param block [Proc] Callback block
    def on(event_type, &block)
      @event_callbacks[event_type] ||= []
      @event_callbacks[event_type] << block
    end

    # Register available tools for tool calling
    #
    # @param tools [Array<RubyLLM::Tool>] Array of tool objects
    def register_tools(tools)
      tools.each do |tool|
        @tools[tool.class.name] = tool
      end
    end

    # Handle incoming event from Nova Sonic
    #
    # @param event_type [Symbol] Type of event
    # @param data [Hash] Event data
    def handle_event(event_type, data)
      case event_type
      when :content_start
        handle_content_start(data)
      when :text_output
        handle_text_output(data)
      when :audio_output
        handle_audio_output(data)
      when :tool_use
        handle_tool_use(data)
      when :content_end
        handle_content_end(data)
      when :completion_end
        handle_completion_end(data)
      when :error
        handle_error(data)
      else
        trigger_callbacks(event_type, data)
      end
    end

    # Trigger barge-in (user interruption)
    def trigger_barge_in
      return unless @can_interrupt && @is_speaking

      @conversation_state = :interrupted
      @is_speaking = false
      
      # Clear any pending audio/text buffers
      @text_buffer = ""
      @audio_buffer.clear

      trigger_callbacks(:barge_in, { message: "User interrupted" })
    end

    # Check if assistant is currently speaking and can be interrupted
    #
    # @return [Boolean] True if barge-in is possible
    def can_barge_in?
      @can_interrupt && @is_speaking
    end

    # Get current conversation state
    #
    # @return [Symbol] Current state (:idle, :listening, :speaking, :processing, :interrupted)
    def state
      @conversation_state
    end

    # Reset handler state
    def reset
      @conversation_state = :idle
      @current_role = nil
      @is_speaking = false
      @text_buffer = ""
      @audio_buffer.clear
    end

    private

    # Handle content start events
    def handle_content_start(data)
      @current_role = data["role"]
      @conversation_state = :processing

      # Check if this is speculative content (can be interrupted)
      if data["additionalModelFields"]
        begin
          additional_fields = JSON.parse(data["additionalModelFields"])
          @can_interrupt = additional_fields["generationStage"] == "SPECULATIVE"
        rescue JSON::ParserError
          @can_interrupt = true # Default to allowing interruption
        end
      end

      trigger_callbacks(:content_start, data)
    end

    # Handle text output events
    def handle_text_output(data)
      return unless data["content"]

      content = data["content"]
      role = data["role"] || @current_role

      # Check for interruption signal
      if content.include?('{ "interrupted" : true }')
        trigger_barge_in
        return
      end

      # Buffer text content
      @text_buffer += content

      # If this is assistant content, we're in speaking mode
      if role == "ASSISTANT"
        @conversation_state = :speaking
        @is_speaking = true
      end

      # Create enhanced data with buffered content
      enhanced_data = data.merge(
        "buffered_content" => @text_buffer,
        "role" => role
      )

      trigger_callbacks(:text_output, enhanced_data)
    end

    # Handle audio output events
    def handle_audio_output(data)
      return unless data["content"] || data["audio_bytes"]

      # Assistant is speaking
      @conversation_state = :speaking
      @is_speaking = true

      # Buffer audio data
      if data["audio_bytes"]
        @audio_buffer << data["audio_bytes"]
      end

      # Create enhanced data with buffered audio
      enhanced_data = data.merge(
        "buffered_audio" => @audio_buffer
      )

      trigger_callbacks(:audio_output, enhanced_data)
    end

    # Handle tool use events
    def handle_tool_use(data)
      @conversation_state = :processing

      tool_name = data["toolName"]
      tool_use_id = data["toolUseId"]
      tool_input = data["input"] || {}

      # Execute tool if available
      if @tools[tool_name]
        begin
          tool_result = execute_tool(tool_name, tool_input)
          
          enhanced_data = data.merge(
            "tool_result" => tool_result,
            "executed" => true
          )
          
          trigger_callbacks(:tool_use, enhanced_data)
          
          # Send tool result back to Nova Sonic would be handled by calling code
        rescue => e
          error_result = { error: e.message }
          
          enhanced_data = data.merge(
            "tool_result" => error_result,
            "executed" => false,
            "error" => e.message
          )
          
          trigger_callbacks(:tool_use, enhanced_data)
        end
      else
        # Tool not available
        enhanced_data = data.merge(
          "tool_result" => { error: "Tool '#{tool_name}' not available" },
          "executed" => false
        )
        
        trigger_callbacks(:tool_use, enhanced_data)
      end
    end

    # Handle content end events
    def handle_content_end(data)
      if data["type"] == "TOOL"
        # Tool execution is complete
        @conversation_state = :listening
      else
        # Regular content is complete
        @conversation_state = :idle
        @is_speaking = false
      end

      trigger_callbacks(:content_end, data)
    end

    # Handle completion end events
    def handle_completion_end(data)
      @conversation_state = :idle
      @is_speaking = false
      @current_role = nil
      
      # Clear buffers
      @text_buffer = ""
      @audio_buffer.clear

      trigger_callbacks(:completion_end, data)
    end

    # Handle error events
    def handle_error(data)
      @conversation_state = :error
      @is_speaking = false

      trigger_callbacks(:error, data)
    end

    # Execute a tool with given input
    #
    # @param tool_name [String] Name of the tool to execute
    # @param tool_input [Hash] Input parameters for the tool
    # @return [Hash] Tool execution result
    def execute_tool(tool_name, tool_input)
      tool = @tools[tool_name]
      return { error: "Tool not found" } unless tool

      # Convert input to proper format expected by RubyLLM tools
      if tool.respond_to?(:execute)
        # Convert hash keys to symbols if needed
        symbolized_input = tool_input.transform_keys(&:to_sym)
        tool.execute(**symbolized_input)
      else
        { error: "Tool does not implement execute method" }
      end
    end

    # Trigger callbacks for event type
    #
    # @param event_type [Symbol] Type of event
    # @param data [Hash] Event data
    def trigger_callbacks(event_type, data)
      callbacks = @event_callbacks[event_type]
      return unless callbacks

      callbacks.each do |callback|
        begin
          callback.call(data)
        rescue => e
          # Log callback errors but don't let them break event processing
          warn "Error in #{event_type} callback: #{e.message}" if $DEBUG
        end
      end
    end
  end
end