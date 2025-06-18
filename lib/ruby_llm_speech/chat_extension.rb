# frozen_string_literal: true

require "securerandom"
require "json"
require "fileutils"

module RubyLLMSpeech
  module ChatExtension
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def speak_with_nova_sonic(**options)
        new.tap do |chat|
          chat.configure_speech(**options)
        end
      end
    end

    attr_accessor :session_id, :audio_handler, :nova_sonic_client
    attr_reader :speech_configuration, :speech_tools, :conversation_transcript

    def configure_speech(
      aws_access_key_id: nil,
      aws_secret_access_key: nil,
      aws_region: nil,
      voice: nil,
      temperature: nil,
      audio_handler: nil,
      session_id: nil,
      system_prompt: nil,
      tools: nil,
      transcript_enabled: true,
      **nova_sonic_options
    )
      @speech_configuration = {
        aws_access_key_id: aws_access_key_id || RubyLLMSpeech.configuration.aws_access_key_id,
        aws_secret_access_key: aws_secret_access_key || RubyLLMSpeech.configuration.aws_secret_access_key,
        aws_region: aws_region || RubyLLMSpeech.configuration.aws_region,
        voice: voice || RubyLLMSpeech.configuration.default_voice,
        temperature: temperature,
        system_prompt: system_prompt,
        transcript_enabled: transcript_enabled,
        **nova_sonic_options
      }

      @session_id = session_id || generate_session_id
      @audio_handler = audio_handler || DefaultAudioHandler.new
      @nova_sonic_client = NovaSonicClient.new(@speech_configuration)
      @speech_tools = tools || []
      @conversation_transcript = ConversationTranscript.new(session_id: @session_id)

      # Set system prompt if provided
      set_system_prompt(system_prompt) if system_prompt

      # Configure tools if provided
      configure_tools(@speech_tools) if @speech_tools.any?

      # Set up transcript callbacks if enabled
      setup_transcript_callbacks if transcript_enabled

      self
    end

    def speak(content = nil, audio_data: nil, &block)
      ensure_speech_configured!

      if content.nil? && audio_data.nil?
        raise ArgumentError, "Either content or audio_data must be provided"
      end

      # Handle text-to-speech if content provided
      if content
        speak_text(content, &block)
      end

      # Handle speech-to-text if audio_data provided
      if audio_data
        speak_audio(audio_data, &block)
      end
    end

    def start_voice_session(&block)
      ensure_speech_configured!

      @nova_sonic_client.start_bidirectional_stream(
        session_id: @session_id,
        audio_handler: @audio_handler,
        &block
      )
    end

    def send_audio(audio_data)
      ensure_speech_configured!
      @nova_sonic_client.send_audio(audio_data)
    end

    def on_audio_received(&block)
      ensure_speech_configured!
      @audio_handler.on_audio_received(&block)
    end

    def on_transcript_received(&block)
      ensure_speech_configured!
      @audio_handler.on_transcript_received(&block)
    end

    def recover_session(session_id)
      old_session_id = @session_id
      @session_id = session_id
      
      begin
        RubyLLMSpeech.logger.info("Recovering session: #{session_id}")
        
        # Attempt to recover Nova Sonic session
        @nova_sonic_client&.recover_session(session_id)
        
        # Try to restore transcript if it exists
        restore_transcript_for_session(session_id) if transcript_enabled?
        
        RubyLLMSpeech.logger.info("Successfully recovered session: #{session_id}")
        self
      rescue StandardError => e
        RubyLLMSpeech.logger.error("Failed to recover session #{session_id}: #{e.message}")
        @session_id = old_session_id
        raise RubyLLMSpeech::SessionError, "Session recovery failed: #{e.message}"
      end
    end

    def close_voice_session
      return unless @session_id

      begin
        RubyLLMSpeech.logger.info("Closing voice session: #{@session_id}")
        
        # Save transcript before closing if enabled
        save_transcript_for_session(@session_id) if transcript_enabled? && @conversation_transcript
        
        @nova_sonic_client&.close_session
        
        RubyLLMSpeech.logger.info("Successfully closed voice session: #{@session_id}")
      rescue StandardError => e
        RubyLLMSpeech.logger.error("Error closing voice session #{@session_id}: #{e.message}")
        # Don't raise error for cleanup operations
      ensure
        @session_id = nil
      end
    end

    def set_system_prompt(prompt)
      @system_prompt = prompt
      # Update the Nova Sonic client with the new system prompt
      @nova_sonic_client&.update_system_prompt(prompt) if @nova_sonic_client
      self
    end

    def get_system_prompt
      @system_prompt
    end

    def update_voice(voice)
      @speech_configuration[:voice] = voice if @speech_configuration
      @nova_sonic_client&.update_voice(voice) if @nova_sonic_client
      self
    end

    def update_temperature(temperature)
      @speech_configuration[:temperature] = temperature if @speech_configuration
      @nova_sonic_client&.update_temperature(temperature) if @nova_sonic_client
      self
    end

    def speech_configured?
      !@speech_configuration.nil? && !@nova_sonic_client.nil?
    end

    def transcript_enabled?
      @speech_configuration&.dig(:transcript_enabled) == true
    end

    def get_transcript(format: :text, **options)
      return nil unless @conversation_transcript

      case format
      when :text
        @conversation_transcript.to_text(**options)
      when :hash
        @conversation_transcript.to_hash
      when :summary
        @conversation_transcript.get_conversation_summary
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end
    end

    def export_transcript(filename, format: :text)
      return false unless @conversation_transcript

      @conversation_transcript.export_to_file(filename, format: format)
      true
    end

    def clear_transcript!
      @conversation_transcript&.clear!
      self
    end

    def add_transcript_message(role:, content:, **options)
      @conversation_transcript&.add_message(role: role, content: content, **options)
      self
    end

    def add_tool(tool)
      @speech_tools ||= []
      @speech_tools << tool
      @nova_sonic_client&.add_tool(tool) if @nova_sonic_client
      self
    end

    def remove_tool(tool_name)
      @speech_tools&.reject! { |tool| tool.class.name.include?(tool_name.to_s) }
      @nova_sonic_client&.remove_tool(tool_name) if @nova_sonic_client
      self
    end

    def list_tools
      @speech_tools&.map { |tool| tool.class.name } || []
    end

    def with_tool(tool)
      add_tool(tool)
      self
    end

    def with_tools(*tools)
      tools.each { |tool| add_tool(tool) }
      self
    end

    def execute_tool_call(tool_name, method_name, arguments)
      tool = find_tool(tool_name)
      
      if tool.nil?
        error_result = { error: "Tool not found: #{tool_name}" }
        @conversation_transcript&.add_error("Tool not found: #{tool_name}", { tool_name: tool_name })
        return error_result
      end

      begin
        # Convert string keys to symbols if arguments is a Hash
        symbolized_args = arguments.is_a?(Hash) ? 
          arguments.transform_keys(&:to_sym) : 
          arguments
        
        result = tool.send(method_name, **symbolized_args)
        success_result = { success: true, result: result }
        
        # Add tool call to transcript
        @conversation_transcript&.add_tool_call(tool_name, method_name, arguments, result)
        
        success_result
      rescue StandardError => e
        error_result = { error: "Tool execution failed: #{e.message}" }
        
        # Add tool error to transcript
        @conversation_transcript&.add_error(
          "Tool execution failed: #{e.message}",
          { tool_name: tool_name, method_name: method_name, arguments: arguments }
        )
        
        error_result
      end
    end

    def retry_with_backoff(max_attempts: nil, &block)
      max_attempts ||= RubyLLMSpeech.configuration.error_retry_attempts
      attempt = 1

      begin
        yield
      rescue RubyLLMSpeech::ConnectionError, RubyLLMSpeech::ModelError => e
        if attempt < max_attempts
          wait_time = 2 ** (attempt - 1) # Exponential backoff
          RubyLLMSpeech.logger.warn("Attempt #{attempt} failed: #{e.message}. Retrying in #{wait_time}s...")
          sleep(wait_time)
          attempt += 1
          retry
        else
          RubyLLMSpeech.logger.error("All #{max_attempts} attempts failed: #{e.message}")
          raise
        end
      end
    end

    def handle_error(error, context = "Unknown operation")
      error_id = SecureRandom.hex(4)
      
      RubyLLMSpeech.logger.error("[#{error_id}] Error in #{context}: #{error.message}")
      RubyLLMSpeech.logger.debug("[#{error_id}] Backtrace: #{error.backtrace.join("\n")}")
      
      # Add error to transcript if available
      @conversation_transcript&.add_error(
        "#{context} failed: #{error.message}",
        { error_id: error_id, error_class: error.class.name }
      )

      # Categorize and re-raise with appropriate error type
      case error
      when Aws::BedrockRuntime::Errors::ServiceError
        raise RubyLLMSpeech::ModelError, "[#{error_id}] AWS service error: #{error.message}"
      when Net::TimeoutError, Timeout::Error
        raise RubyLLMSpeech::ConnectionError, "[#{error_id}] Connection timeout: #{error.message}"
      when JSON::ParserError
        raise RubyLLMSpeech::ModelError, "[#{error_id}] Invalid response format: #{error.message}"
      when ArgumentError
        raise RubyLLMSpeech::ConfigurationError, "[#{error_id}] Configuration error: #{error.message}"
      else
        raise RubyLLMSpeech::Error, "[#{error_id}] Unexpected error: #{error.message}"
      end
    end

    private

    def speak_text(content, &block)
      # Add user text input to transcript
      @conversation_transcript&.add_message(
        role: :user,
        content: content,
        type: :text,
        metadata: { input_method: "text_to_speech" }
      )

      # Send text to Nova Sonic for text-to-speech with retry logic
      result = retry_with_backoff do
        @nova_sonic_client.text_to_speech(
          text: content,
          voice: @speech_configuration[:voice],
          session_id: @session_id,
          &block
        )
      end

      # Add assistant response to transcript
      @conversation_transcript&.add_assistant_speech(
        content,
        { voice: @speech_configuration[:voice], type: "text_to_speech" }
      )

      result
    rescue StandardError => e
      handle_error(e, "Text-to-speech conversion")
    end

    def speak_audio(audio_data, &block)
      # Add audio input to transcript (transcript will be updated by callback when processed)
      @conversation_transcript&.add_message(
        role: :user,
        content: "Audio input received",
        type: :audio_input,
        metadata: { audio_length: audio_data.length }
      )

      # Send audio to Nova Sonic for speech-to-text and processing with retry logic
      retry_with_backoff do
        @nova_sonic_client.speech_to_text(
          audio_data: audio_data,
          session_id: @session_id,
          &block
        )
      end
    rescue StandardError => e
      handle_error(e, "Speech-to-text conversion")
    end

    def save_transcript_for_session(session_id)
      return unless @conversation_transcript

      filename = "transcript_#{session_id}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
      transcript_dir = ensure_transcript_directory
      full_path = File.join(transcript_dir, filename)
      
      @conversation_transcript.export_to_file(full_path, format: :json)
      RubyLLMSpeech.logger.info("Transcript saved to: #{full_path}")
      full_path
    rescue StandardError => e
      RubyLLMSpeech.logger.warn("Failed to save transcript: #{e.message}")
      nil
    end

    def restore_transcript_for_session(session_id)
      transcript_dir = File.join(Dir.home, ".ruby_llm_speech", "transcripts")
      return unless Dir.exist?(transcript_dir)

      # Look for the most recent transcript for this session
      pattern = File.join(transcript_dir, "transcript_#{session_id}_*.json")
      transcript_files = Dir.glob(pattern).sort.last

      return unless transcript_files

      begin
        transcript_data = JSON.parse(File.read(transcript_files))
        # Restore basic session information
        @conversation_transcript.instance_variable_set(:@started_at, Time.parse(transcript_data["started_at"]))
        RubyLLMSpeech.logger.info("Transcript restored from: #{transcript_files}")
      rescue StandardError => e
        RubyLLMSpeech.logger.warn("Failed to restore transcript: #{e.message}")
      end
    end

    def ensure_transcript_directory
      transcript_dir = File.join(Dir.home, ".ruby_llm_speech", "transcripts")
      FileUtils.mkdir_p(transcript_dir) unless Dir.exist?(transcript_dir)
      transcript_dir
    end

    def ensure_speech_configured!
      return if @speech_configuration && @nova_sonic_client

      raise RubyLLMSpeech::Error, "Speech not configured. Call configure_speech first."
    end

    def generate_session_id
      "ruby_llm_speech_#{Time.now.to_i}_#{SecureRandom.hex(8)}"
    end

    def configure_tools(tools)
      tools.each { |tool| validate_tool(tool) }
      @nova_sonic_client&.configure_tools(tools)
    end

    def validate_tool(tool)
      unless tool.respond_to?(:execute) || tool.class.instance_methods.any? { |m| m.to_s != "execute" && !m.to_s.start_with?("_") }
        raise RubyLLMSpeech::Error, "Tool #{tool.class.name} must implement executable methods"
      end
    end

    def find_tool(tool_name)
      @speech_tools&.find { |tool| tool.class.name.include?(tool_name.to_s) }
    end

    def setup_transcript_callbacks
      return unless @audio_handler && @conversation_transcript

      # Set up callbacks to capture audio and transcript events
      @audio_handler.on_transcript_received do |transcript, metadata|
        @conversation_transcript.add_user_speech(transcript, metadata)
      end

      @audio_handler.on_audio_received do |audio_data, metadata|
        # Log when audio is received (could be from assistant)
        if metadata[:type] == "assistant_response"
          @conversation_transcript.add_assistant_speech("Audio response received", metadata)
        end
      end

      # Add system message if system prompt is set
      if @speech_configuration[:system_prompt]
        @conversation_transcript.add_system_message(@speech_configuration[:system_prompt])
      end
    end
  end
end