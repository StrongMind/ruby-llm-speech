# frozen_string_literal: true

require "aws-sdk-bedrockruntime"
require "base64"
require "json"
require "securerandom"

module RubyLLMSpeech
  # Client for interacting with Amazon Nova Sonic via AWS Bedrock's bidirectional streaming API
  class NovaSonicClient
    attr_reader :configuration, :session_id, :active

    # Initialize Nova Sonic client
    #
    # @param configuration [Configuration] Configuration object with AWS credentials
    def initialize(configuration = nil)
      @configuration = configuration || RubyLLMSpeech.configuration
      @session_id = nil
      @active = false
      @event_callbacks = {}
      @message_history = []
      @client = nil
      @stream_response = nil
    end

    # Start a new speech session
    #
    # @param system_prompt [String, nil] Optional system prompt for the conversation
    # @param message_history [Array<Hash>] Optional message history for conversation resumption
    # @yield [event_type, data] Block called for each event received
    # @return [String] Session ID
    def start_session(system_prompt: nil, message_history: [], &block)
      @configuration.validate!
      @session_id = SecureRandom.uuid
      @active = true
      @message_history = message_history.dup
      
      # Initialize AWS client if not already done
      initialize_aws_client

      # Start bidirectional streaming
      start_bidirectional_stream

      # Send session start event
      send_session_start_event(system_prompt)

      # Start processing responses in background
      Thread.new { process_responses(&block) }

      @session_id
    end

    # Stop the current session
    def stop_session
      return unless @active

      @active = false
      
      # Send session end event if needed
      send_session_end_event if @stream_response

      @session_id = nil
    end

    # Send audio data to Nova Sonic
    #
    # @param audio_data [String] Base64 encoded audio data
    def send_audio(audio_data)
      raise Error, "Session not active" unless @active

      event = {
        event: {
          audioInput: {
            content: audio_data,
            contentType: "audio/pcm"
          }
        }
      }

      send_event(event)
    end

    # Send text input to Nova Sonic
    #
    # @param text [String] Text to send
    def send_text(text)
      raise Error, "Session not active" unless @active

      event = {
        event: {
          textInput: {
            content: text
          }
        }
      }

      send_event(event)
    end

    # Register callback for specific event types
    #
    # @param event_type [Symbol] Event type (:audio_output, :text_output, :content_start, etc.)
    # @param block [Proc] Callback block
    def on(event_type, &block)
      @event_callbacks[event_type] = block
    end

    # Check if session is active
    #
    # @return [Boolean] True if session is active
    def active?
      @active
    end

    private

    # Initialize AWS Bedrock client
    def initialize_aws_client
      credentials = @configuration.aws_credentials
      
      @client = Aws::BedrockRuntime::Client.new(
        access_key_id: credentials[:access_key_id],
        secret_access_key: credentials[:secret_access_key],
        session_token: credentials[:session_token],
        region: credentials[:region],
        http_wire_trace: false
      )
    end

    # Start bidirectional streaming connection
    def start_bidirectional_stream
      request = {
        model_id: @configuration.model_id
      }

      @stream_response = @client.invoke_model_with_bidirectional_stream(request) do |stream|
        stream.on_event do |event|
          # This will be handled by process_responses
        end

        stream.on_error do |error|
          handle_stream_error(error)
        end

        stream.on_complete do
          @active = false
        end
      end
    end

    # Send session start event with configuration
    #
    # @param system_prompt [String, nil] Optional system prompt
    def send_session_start_event(system_prompt = nil)
      event = {
        event: {
          sessionStart: {
            inferenceConfiguration: @configuration.inference_config
          }
        }
      }

      # Add system prompt if provided
      if system_prompt
        event[:event][:sessionStart][:systemPrompt] = system_prompt
      end

      # Add message history if present
      if @message_history.any?
        event[:event][:sessionStart][:messageHistory] = @message_history
      end

      send_event(event)
    end

    # Send session end event
    def send_session_end_event
      event = {
        event: {
          sessionEnd: {}
        }
      }

      send_event(event)
    end

    # Send event to the stream
    #
    # @param event [Hash] Event data
    def send_event(event)
      return unless @stream_response && @active

      event_json = JSON.generate(event)
      
      chunk = {
        chunk: {
          bytes: event_json
        }
      }

      @stream_response.signal(chunk)
    rescue => e
      handle_error("Failed to send event", e)
    end

    # Process responses from the stream
    #
    # @yield [event_type, data] Block called for each event
    def process_responses(&block)
      return unless @stream_response

      @stream_response.each do |response|
        break unless @active

        next unless response.chunk&.bytes

        begin
          response_data = response.chunk.bytes
          json_data = JSON.parse(response_data)

          process_event(json_data, &block)
        rescue JSON::ParserError => e
          handle_error("Failed to parse response JSON", e)
        rescue => e
          handle_error("Error processing response", e)
        end
      end
    rescue => e
      handle_error("Error in response processing loop", e)
    ensure
      @active = false
    end

    # Process individual events from Nova Sonic
    #
    # @param json_data [Hash] Parsed JSON event data
    # @yield [event_type, data] Block called for each event
    def process_event(json_data, &block)
      return unless json_data["event"]

      event = json_data["event"]

      case
      when event["contentStart"]
        handle_content_start(event["contentStart"], &block)
      when event["textOutput"]
        handle_text_output(event["textOutput"], &block)
      when event["audioOutput"]
        handle_audio_output(event["audioOutput"], &block)
      when event["toolUse"]
        handle_tool_use(event["toolUse"], &block)
      when event["contentEnd"]
        handle_content_end(event["contentEnd"], &block)
      when event["completionEnd"]
        handle_completion_end(event["completionEnd"], &block)
      else
        # Handle unknown event types
        trigger_callback(:unknown_event, event, &block)
      end
    end

    # Handle content start events
    def handle_content_start(data, &block)
      trigger_callback(:content_start, data, &block)
    end

    # Handle text output events
    def handle_text_output(data, &block)
      # Add to message history if it's a complete message
      if data["role"] && data["content"]
        @message_history << {
          role: data["role"],
          content: data["content"]
        }
      end

      trigger_callback(:text_output, data, &block)
    end

    # Handle audio output events
    def handle_audio_output(data, &block)
      # Decode base64 audio content
      if data["content"]
        audio_bytes = Base64.decode64(data["content"])
        data = data.merge("audio_bytes" => audio_bytes)
      end

      trigger_callback(:audio_output, data, &block)
    end

    # Handle tool use events
    def handle_tool_use(data, &block)
      trigger_callback(:tool_use, data, &block)
    end

    # Handle content end events
    def handle_content_end(data, &block)
      trigger_callback(:content_end, data, &block)
    end

    # Handle completion end events
    def handle_completion_end(data, &block)
      @active = false
      trigger_callback(:completion_end, data, &block)
    end

    # Trigger registered callback and yield to block
    def trigger_callback(event_type, data, &block)
      # Call registered callback if present
      callback = @event_callbacks[event_type]
      callback&.call(data)

      # Yield to block if present
      block&.call(event_type, data)
    end

    # Handle stream errors
    def handle_stream_error(error)
      @active = false
      
      error_data = {
        message: error.message,
        class: error.class.name
      }

      trigger_callback(:error, error_data)
    end

    # Handle general errors
    def handle_error(message, error)
      error_data = {
        message: "#{message}: #{error.message}",
        class: error.class.name,
        backtrace: error.backtrace&.first(5)
      }

      trigger_callback(:error, error_data)
    end
  end
end