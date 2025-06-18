# frozen_string_literal: true

module RubyLLMSpeech
  # Module that extends RubyLLM::Chat with speech functionality
  # This module is prepended to RubyLLM::Chat to add speech methods
  module ChatExtensions
    # @return [NovaSonicClient, nil] The current Nova Sonic client
    attr_reader :speech_client

    # @return [EventHandler, nil] The current event handler
    attr_reader :speech_event_handler

    # @return [Array<Proc>] Callbacks for audio received events
    attr_reader :audio_received_callbacks

    # Initialize speech-related instance variables
    def initialize(*args, **kwargs)
      super
      @speech_client = nil
      @speech_event_handler = nil
      @audio_received_callbacks = []
      @speech_active = false
      @speech_configuration = nil
    end

    # Start a speech conversation with Nova Sonic
    # This method handles both audio and text output simultaneously
    #
    # @param system_prompt [String, nil] Optional system prompt for the conversation
    # @param message_history [Array<Hash>] Optional message history for conversation resumption
    # @param configuration [Configuration, nil] Optional custom configuration
    # @yield [chunk] Block called for each text chunk received (for transcript display)
    # @yieldparam chunk [OpenStruct] Chunk object with content, role, and other metadata
    # @return [String] Session ID for the speech conversation
    # @example
    #   chat.speak do |chunk|
    #     print chunk.content
    #   end
    def speak(system_prompt: nil, message_history: [], configuration: nil, &block)
      ensure_nova_sonic_model
      setup_speech_session(configuration)

      @speech_active = true

      # Set up event handlers for both audio and text
      setup_speech_event_handlers(&block)

      # Start Nova Sonic session
      session_id = @speech_client.start_session(
        system_prompt: system_prompt,
        message_history: message_history
      ) do |event_type, data|
        @speech_event_handler.handle_event(event_type, data)
      end

      session_id
    end

    # Resume a speech conversation with message history
    # This enables continuing interrupted conversations
    #
    # @param message_history [Array<Hash>] Message history to resume from
    # @param system_prompt [String, nil] Optional system prompt
    # @param configuration [Configuration, nil] Optional custom configuration
    # @yield [chunk] Block called for each text chunk received
    # @return [String] Session ID for the resumed speech conversation
    def resume_speech(message_history, system_prompt: nil, configuration: nil, &block)
      speak(
        system_prompt: system_prompt,
        message_history: message_history,
        configuration: configuration,
        &block
      )
    end

    # Send audio data to the current speech session
    #
    # @param audio_data [String] Base64 encoded audio data
    # @raise [Error] If no speech session is active
    # @example
    #   handler.on_audio_received do |audio_data|
    #     chat.send_audio(audio_data)
    #   end
    def send_audio(audio_data)
      raise Error, "No active speech session" unless @speech_client&.active?

      @speech_client.send_audio(audio_data)
    end

    # Send text input to the current speech session
    # This can be used alongside audio input
    #
    # @param text [String] Text to send
    # @raise [Error] If no speech session is active
    def send_text_to_speech(text)
      raise Error, "No active speech session" unless @speech_client&.active?

      @speech_client.send_text(text)
    end

    # Register callback for when audio is received from Nova Sonic
    # This enables playing audio responses to the user
    #
    # @yield [audio_data] Block called when audio is received from the model
    # @yieldparam audio_data [String] Raw audio bytes to play
    # @example
    #   chat.on_audio_received do |audio|
    #     handler.play_audio(audio)
    #   end
    def on_audio_received(&block)
      @audio_received_callbacks << block if block
    end

    # Stop the current speech session
    def stop_speech
      return unless @speech_client

      @speech_client.stop_session
      @speech_active = false
    end

    # Check if a speech session is currently active
    #
    # @return [Boolean] True if speech session is active
    def speech_active?
      @speech_active && @speech_client&.active?
    end

    # Get current conversation state from the event handler
    #
    # @return [Symbol, nil] Current conversation state or nil if no session
    def speech_state
      @speech_event_handler&.state
    end

    # Check if the assistant is currently speaking and can be interrupted
    #
    # @return [Boolean] True if barge-in is possible
    def can_interrupt?
      @speech_event_handler&.can_barge_in? || false
    end

    # Trigger a barge-in (user interruption) during assistant speech
    def interrupt_speech
      @speech_event_handler&.trigger_barge_in
    end

    # Get message history from current speech session
    #
    # @return [Array<Hash>] Message history
    def speech_message_history
      @speech_client&.instance_variable_get(:@message_history) || []
    end

    # Configure speech-specific settings
    #
    # @param voice_id [String, nil] Voice ID for Nova Sonic
    # @param model_id [String, nil] Model ID (should be Nova Sonic)
    # @param inference_config [Hash, nil] Custom inference configuration
    def configure_speech(voice_id: nil, model_id: nil, inference_config: nil)
      @speech_configuration ||= {}
      @speech_configuration[:voice_id] = voice_id if voice_id
      @speech_configuration[:model_id] = model_id if model_id
      @speech_configuration[:inference_config] = inference_config if inference_config
    end

    private

    # Ensure the chat is configured to use Nova Sonic model
    def ensure_nova_sonic_model
      current_model = instance_variable_get(:@model) || "gpt-4o-mini"
      
      unless current_model.include?("nova-sonic")
        warn "Current model '#{current_model}' is not Nova Sonic. " \
             "Speech functionality requires amazon.nova-sonic-v1:0 model."
      end
    end

    # Set up speech session with configuration
    #
    # @param configuration [Configuration, nil] Custom configuration
    def setup_speech_session(configuration = nil)
      config = configuration || build_speech_configuration
      
      @speech_client = NovaSonicClient.new(config)
      @speech_event_handler = EventHandler.new

      # Register tools from the current chat instance if available
      register_speech_tools
    end

    # Build speech configuration from global config and local overrides
    #
    # @return [Configuration] Speech configuration
    def build_speech_configuration
      # Start with global configuration
      config = RubyLLMSpeech.configuration.dup

      # Apply any local speech configuration
      if @speech_configuration
        @speech_configuration.each do |key, value|
          config.public_send("#{key}=", value) if config.respond_to?("#{key}=")
        end
      end

      config
    end

    # Register tools from RubyLLM chat with the speech event handler
    def register_speech_tools
      # Get tools from the current chat instance
      tools = instance_variable_get(:@tools) || []
      
      if tools.any?
        @speech_event_handler.register_tools(tools)
      end
    end

    # Set up event handlers for speech events
    #
    # @yield [chunk] Block for text output chunks
    def setup_speech_event_handlers(&block)
      # Handle text output for transcript display
      @speech_event_handler.on(:text_output) do |data|
        next unless block && data["content"]

        # Create a chunk object similar to RubyLLM's streaming chunks
        chunk = create_text_chunk(data)
        block.call(chunk)
      end

      # Handle audio output
      @speech_event_handler.on(:audio_output) do |data|
        next unless data["audio_bytes"]

        # Trigger all registered audio callbacks
        @audio_received_callbacks.each do |callback|
          begin
            callback.call(data["audio_bytes"])
          rescue => e
            warn "Error in audio callback: #{e.message}" if $DEBUG
          end
        end
      end

      # Handle tool use events
      @speech_event_handler.on(:tool_use) do |data|
        # Tool results are automatically sent back to Nova Sonic by EventHandler
        # We could add logging or other handling here if needed
      end

      # Handle conversation state changes
      @speech_event_handler.on(:completion_end) do |data|
        @speech_active = false
      end

      # Handle errors
      @speech_event_handler.on(:error) do |data|
        warn "Speech error: #{data[:message]}" if $DEBUG
        @speech_active = false
      end
    end

    # Create a text chunk object compatible with RubyLLM's streaming interface
    #
    # @param data [Hash] Text output data from Nova Sonic
    # @return [OpenStruct] Chunk object
    def create_text_chunk(data)
      chunk = OpenStruct.new
      chunk.content = data["content"] || ""
      chunk.role = data["role"] || "assistant"
      chunk.buffered_content = data["buffered_content"] || chunk.content
      chunk.metadata = {
        source: "nova_sonic",
        event_type: "text_output",
        timestamp: Time.now
      }
      chunk
    end
  end
end