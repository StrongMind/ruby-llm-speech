# frozen_string_literal: true

require "aws-sdk-bedrockruntime"
require "json"
require "base64"

module RubyLLMSpeech
  class NovaSonicClient
    attr_reader :session_id, :configuration, :tools

    def initialize(configuration)
      @configuration = configuration
      @client = nil
      @active_streams = {}
      @session_data = {}
      @tools = []
    end

    def start_bidirectional_stream(session_id:, audio_handler:, &block)
      @session_id = session_id
      ensure_client!

      model_id = "amazon.nova-sonic-1:0" # Nova Sonic model ID

      # Create the initial request payload for Nova Sonic
      initial_request = build_initial_request(session_id)

      begin
        # Start bidirectional streaming with Nova Sonic
        response = @client.invoke_model_with_bidirectional_stream(
          model_id: model_id,
          request_body: initial_request
        )

        # Store the stream for this session
        @active_streams[session_id] = response

        # Handle the streaming response
        handle_bidirectional_stream(response, audio_handler, &block)

      rescue Aws::BedrockRuntime::Errors::ServiceError => e
        handle_aws_error(e)
      rescue StandardError => e
        raise RubyLLMSpeech::ConnectionError, "Failed to start voice session: #{e.message}"
      end
    end

    def send_audio(audio_data)
      ensure_session_active!

      # Encode audio data for Nova Sonic
      encoded_audio = encode_audio_for_nova_sonic(audio_data)

      # Send audio chunk to the active stream
      stream = @active_streams[@session_id]
      audio_event = build_audio_event(encoded_audio)

      stream.write(audio_event)
    rescue StandardError => e
      raise RubyLLMSpeech::AudioError, "Failed to send audio: #{e.message}"
    end

    def text_to_speech(text:, voice:, session_id:, &block)
      @session_id = session_id
      ensure_client!

      model_id = "amazon.nova-sonic-1:0"

      request_payload = {
        text: text,
        voice: voice,
        output_format: "pcm",
        sample_rate: 16000,
        session_id: session_id
      }

      begin
        response = @client.invoke_model(
          model_id: model_id,
          content_type: "application/json",
          body: request_payload.to_json
        )

        audio_data = decode_nova_sonic_response(response.body.read)
        
        if block_given?
          yield audio_data
        else
          audio_data
        end

      rescue Aws::BedrockRuntime::Errors::ServiceError => e
        handle_aws_error(e)
      rescue StandardError => e
        raise RubyLLMSpeech::ModelError, "Text-to-speech failed: #{e.message}"
      end
    end

    def speech_to_text(audio_data:, session_id:, &block)
      @session_id = session_id
      ensure_client!

      model_id = "amazon.nova-sonic-1:0"
      encoded_audio = encode_audio_for_nova_sonic(audio_data)

      request_payload = {
        audio: encoded_audio,
        input_format: "pcm",
        sample_rate: 16000,
        session_id: session_id
      }

      begin
        response = @client.invoke_model(
          model_id: model_id,
          content_type: "application/json",
          body: request_payload.to_json
        )

        transcript = decode_nova_sonic_transcript(response.body.read)
        
        if block_given?
          yield transcript
        else
          transcript
        end

      rescue Aws::BedrockRuntime::Errors::ServiceError => e
        handle_aws_error(e)
      rescue StandardError => e
        raise RubyLLMSpeech::ModelError, "Speech-to-text failed: #{e.message}"
      end
    end

    def recover_session(session_id)
      @session_id = session_id
      # Restore session data if available
      @session_data[session_id] ||= {}
    end

    def close_session
      return unless @session_id && @active_streams[@session_id]

      stream = @active_streams[@session_id]
      stream.close if stream.respond_to?(:close)
      @active_streams.delete(@session_id)
      @session_data.delete(@session_id)
    end

    def update_system_prompt(prompt)
      @configuration[:system_prompt] = prompt
      # Update any active sessions with the new system prompt
      update_session_configuration if @session_id
    end

    def update_voice(voice)
      @configuration[:voice] = voice
      update_session_configuration if @session_id
    end

    def update_temperature(temperature)
      @configuration[:temperature] = temperature
      update_session_configuration if @session_id
    end

    def configure_tools(tools)
      @tools = tools
      update_session_configuration if @session_id
    end

    def add_tool(tool)
      @tools << tool unless @tools.include?(tool)
      update_session_configuration if @session_id
    end

    def remove_tool(tool_name)
      @tools.reject! { |tool| tool.class.name.include?(tool_name.to_s) }
      update_session_configuration if @session_id
    end

    private

    def ensure_client!
      return if @client

      @client = Aws::BedrockRuntime::Client.new(
        access_key_id: @configuration[:aws_access_key_id],
        secret_access_key: @configuration[:aws_secret_access_key],
        region: @configuration[:aws_region]
      )
    rescue StandardError => e
      raise RubyLLMSpeech::AuthenticationError, "Failed to create AWS client: #{e.message}"
    end

    def ensure_session_active!
      raise RubyLLMSpeech::SessionError, "No active session" unless @session_id
      raise RubyLLMSpeech::SessionError, "Session stream not active" unless @active_streams[@session_id]
    end

    def build_initial_request(session_id)
      request = {
        session_id: session_id,
        configuration: {
          voice: @configuration[:voice],
          temperature: @configuration[:temperature],
          input_format: "pcm",
          output_format: "pcm",
          sample_rate: 16000,
          stream_mode: "bidirectional"
        }
      }

      # Add system prompt if provided
      if @configuration[:system_prompt]
        request[:system_prompt] = @configuration[:system_prompt]
      end

      # Add tool definitions if tools are available
      if @tools.any?
        request[:tools] = build_tool_definitions
      end

      request.to_json
    end

    def build_audio_event(encoded_audio)
      {
        audio_chunk: {
          audio: encoded_audio,
          timestamp: Time.now.to_f
        }
      }.to_json
    end

    def handle_bidirectional_stream(stream, audio_handler, &block)
      Thread.new do
        begin
          stream.each do |event|
            case event
            when :audio_chunk
              # Handle incoming audio from Nova Sonic
              audio_data = decode_audio_chunk(event.audio_chunk)
              audio_handler.handle_audio_received(audio_data)
              yield(audio_data) if block_given?

            when :transcript
              # Handle transcript from Nova Sonic
              transcript_data = event.transcript
              audio_handler.handle_transcript_received(transcript_data.text, {
                confidence: transcript_data.confidence,
                timestamp: transcript_data.timestamp
              })

            when :tool_call
              # Handle tool call from Nova Sonic
              handle_tool_call(event.tool_call, audio_handler)

            when :error
              handle_stream_error(event.error)

            when :stream_end
              break
            end
          end
        rescue StandardError => e
          raise RubyLLMSpeech::ConnectionError, "Stream error: #{e.message}"
        ensure
          close_session
        end
      end
    end

    def encode_audio_for_nova_sonic(audio_data)
      # Convert audio data to the format expected by Nova Sonic
      case audio_data
      when Array
        # Assume PCM data as array of integers
        audio_data.pack("s*") # 16-bit signed integers
      when String
        # Assume already encoded audio data
        audio_data
      else
        raise RubyLLMSpeech::AudioError, "Unsupported audio data format: #{audio_data.class}"
      end.then { |data| Base64.encode64(data) }
    end

    def decode_nova_sonic_response(response_body)
      response_data = JSON.parse(response_body)
      
      if response_data["audio"]
        Base64.decode64(response_data["audio"])
      else
        raise RubyLLMSpeech::ModelError, "No audio data in response"
      end
    rescue JSON::ParserError => e
      raise RubyLLMSpeech::ModelError, "Invalid response format: #{e.message}"
    end

    def decode_nova_sonic_transcript(response_body)
      response_data = JSON.parse(response_body)
      
      if response_data["transcript"]
        response_data["transcript"]
      else
        raise RubyLLMSpeech::ModelError, "No transcript data in response"
      end
    rescue JSON::ParserError => e
      raise RubyLLMSpeech::ModelError, "Invalid response format: #{e.message}"
    end

    def decode_audio_chunk(audio_chunk)
      Base64.decode64(audio_chunk.audio)
    end

    def handle_aws_error(error)
      case error
      when Aws::BedrockRuntime::Errors::AccessDeniedException
        raise RubyLLMSpeech::AuthenticationError, "AWS access denied: #{error.message}"
      when Aws::BedrockRuntime::Errors::ValidationException
        raise RubyLLMSpeech::ModelError, "Invalid request: #{error.message}"
      when Aws::BedrockRuntime::Errors::ResourceNotFoundException
        raise RubyLLMSpeech::ModelError, "Model not found: #{error.message}"
      when Aws::BedrockRuntime::Errors::ThrottlingException
        raise RubyLLMSpeech::ConnectionError, "Request throttled: #{error.message}"
      else
        raise RubyLLMSpeech::Error, "AWS error: #{error.message}"
      end
    end

    def handle_stream_error(error)
      raise RubyLLMSpeech::ConnectionError, "Stream error: #{error.message}"
    end

    def update_session_configuration
      return unless @active_streams[@session_id]

      # Send configuration update to active stream
      config_update = {
        configuration_update: {
          voice: @configuration[:voice],
          temperature: @configuration[:temperature],
          system_prompt: @configuration[:system_prompt],
          tools: @tools.any? ? build_tool_definitions : nil
        }
      }.to_json

      stream = @active_streams[@session_id]
      stream.write(config_update) if stream.respond_to?(:write)
    rescue StandardError => e
      # Log error but don't fail - configuration will be applied on next interaction
      puts "Warning: Could not update session configuration: #{e.message}"
    end

    def build_tool_definitions
      @tools.map do |tool|
        {
          name: tool.class.name,
          description: tool.class.description || "Tool for #{tool.class.name}",
          parameters: extract_tool_parameters(tool)
        }
      end
    end

    def extract_tool_parameters(tool)
      # Extract parameters from tool definition
      # This would integrate with RubyLLM::Tool structure
      if tool.respond_to?(:parameters)
        tool.parameters
      else
        # Fallback - extract from method signatures
        {}
      end
    end

    def handle_tool_call(tool_call_data, audio_handler)
      tool_name = tool_call_data.tool_name
      method_name = tool_call_data.method_name || "execute"
      arguments = tool_call_data.arguments || {}
      tool_call_id = tool_call_data.tool_call_id

      # Find the tool
      tool = @tools.find { |t| t.class.name.include?(tool_name) }
      
      if tool
        begin
          # Execute the tool
          symbolized_args = arguments.is_a?(Hash) ? 
            arguments.transform_keys(&:to_sym) : 
            arguments
          
          result = tool.send(method_name.to_sym, **symbolized_args)
          
          # Send tool result back to Nova Sonic
          send_tool_result(tool_call_id, result)
          
          # Notify audio handler about tool execution
          audio_handler.handle_transcript_received(
            "Tool executed: #{tool_name}.#{method_name} -> #{result}",
            { type: "tool_execution", tool_name: tool_name, result: result }
          )
        rescue StandardError => e
          # Send error result back to Nova Sonic
          send_tool_result(tool_call_id, { error: e.message })
          
          audio_handler.handle_transcript_received(
            "Tool execution failed: #{e.message}",
            { type: "tool_error", tool_name: tool_name, error: e.message }
          )
        end
      else
        error_msg = "Tool not found: #{tool_name}"
        send_tool_result(tool_call_id, { error: error_msg })
        audio_handler.handle_transcript_received(error_msg, { type: "tool_error" })
      end
    end

    def send_tool_result(tool_call_id, result)
      return unless @active_streams[@session_id]

      tool_result_event = {
        tool_result: {
          tool_call_id: tool_call_id,
          result: result,
          timestamp: Time.now.to_f
        }
      }.to_json

      stream = @active_streams[@session_id]
      stream.write(tool_result_event) if stream.respond_to?(:write)
    rescue StandardError => e
      puts "Warning: Could not send tool result: #{e.message}"
    end
  end
end