# frozen_string_literal: true

require "base64"

module RubyLLMSpeech
  # Interface class for audio input/output management
  # This provides the contract that external audio handler implementations should follow
  class AudioHandler
    # @return [Proc, nil] Callback for when audio is received from user
    attr_accessor :on_audio_received_callback

    # @return [Proc, nil] Callback for when audio should be played to user
    attr_accessor :play_audio_callback

    # Initialize audio handler with default configuration
    def initialize
      @on_audio_received_callback = nil
      @play_audio_callback = nil
      @recording = false
      @playing = false
    end

    # Set callback for when audio is received from user input (microphone)
    #
    # @yield [audio_data] Block called when audio is received
    # @yieldparam audio_data [String] Base64 encoded audio data
    # @example
    #   handler.on_audio_received do |audio_data|
    #     chat.send_audio(audio_data)
    #   end
    def on_audio_received(&block)
      @on_audio_received_callback = block
    end

    # Set callback for when audio should be played to user (speakers)
    #
    # @yield [audio_data] Block called when audio should be played
    # @yieldparam audio_data [String] Raw audio bytes
    # @example
    #   handler.play_audio do |audio_data|
    #     speaker.play(audio_data)
    #   end
    def play_audio(&block)
      @play_audio_callback = block
    end

    # Start recording audio from user
    # This is a placeholder method that should be implemented by concrete handlers
    def start_recording
      @recording = true
      raise NotImplementedError, "Subclasses must implement start_recording"
    end

    # Stop recording audio from user
    # This is a placeholder method that should be implemented by concrete handlers
    def stop_recording
      @recording = false
      raise NotImplementedError, "Subclasses must implement stop_recording"
    end

    # Play audio data to user
    # This is a placeholder method that should be implemented by concrete handlers
    #
    # @param audio_data [String] Raw audio bytes to play
    def play(audio_data)
      @playing = true
      
      if @play_audio_callback
        @play_audio_callback.call(audio_data)
      else
        raise NotImplementedError, "No play_audio callback set or subclass implementation"
      end
    ensure
      @playing = false
    end

    # Check if currently recording
    #
    # @return [Boolean] True if recording is active
    def recording?
      @recording
    end

    # Check if currently playing
    #
    # @return [Boolean] True if playback is active
    def playing?
      @playing
    end

    # Convert raw audio bytes to base64 for transmission to Nova Sonic
    #
    # @param audio_bytes [String] Raw audio bytes
    # @param content_type [String] MIME type of audio data (default: "audio/pcm")
    # @return [String] Base64 encoded audio data
    def encode_audio(audio_bytes, content_type: "audio/pcm")
      validate_audio_format(content_type)
      Base64.strict_encode64(audio_bytes)
    end

    # Convert base64 audio data to raw bytes
    #
    # @param encoded_audio [String] Base64 encoded audio data
    # @return [String] Raw audio bytes
    def decode_audio(encoded_audio)
      Base64.decode64(encoded_audio)
    rescue ArgumentError => e
      raise Error, "Invalid base64 audio data: #{e.message}"
    end

    # Validate audio format requirements for Nova Sonic
    #
    # @param content_type [String] MIME type to validate
    # @raise [Error] If content type is not supported
    def validate_audio_format(content_type)
      supported_formats = %w[
        audio/pcm
        audio/wav
        audio/mp3
        audio/m4a
        audio/flac
        audio/ogg
      ]

      unless supported_formats.include?(content_type.downcase)
        raise Error, "Unsupported audio format: #{content_type}. " \
                     "Supported formats: #{supported_formats.join(', ')}"
      end
    end

    # Get recommended audio configuration for Nova Sonic
    #
    # @return [Hash] Recommended audio settings
    def self.recommended_config
      {
        sample_rate: 16_000,   # 16 kHz
        channels: 1,           # Mono
        format: "pcm",         # PCM format
        bit_depth: 16,         # 16-bit
        content_type: "audio/pcm"
      }
    end

    # Convert audio to recommended format
    # This is a placeholder method that should be implemented by concrete handlers
    # that have access to audio processing libraries
    #
    # @param audio_data [String] Raw audio bytes
    # @param from_format [Hash] Source audio format
    # @param to_format [Hash] Target audio format (defaults to recommended)
    # @return [String] Converted audio bytes
    def convert_audio_format(audio_data, from_format:, to_format: nil)
      to_format ||= self.class.recommended_config

      # If formats match, no conversion needed
      return audio_data if formats_match?(from_format, to_format)

      # Concrete implementations should override this method
      raise NotImplementedError, "Audio format conversion not implemented. " \
                                 "Consider using an audio processing library like FFI::PortAudio"
    end

    # Validate that audio meets Nova Sonic requirements
    #
    # @param audio_data [String] Audio data to validate
    # @param format [Hash] Audio format information
    # @raise [Error] If audio doesn't meet requirements
    def validate_audio_data(audio_data, format)
      if audio_data.nil? || audio_data.empty?
        raise Error, "Audio data cannot be empty"
      end

      recommended = self.class.recommended_config

      # Check sample rate
      if format[:sample_rate] && format[:sample_rate] != recommended[:sample_rate]
        warn "Audio sample rate #{format[:sample_rate]} differs from recommended " \
             "#{recommended[:sample_rate]}. Consider resampling for optimal results."
      end

      # Check channels
      if format[:channels] && format[:channels] != recommended[:channels]
        warn "Audio has #{format[:channels]} channels, recommended is " \
             "#{recommended[:channels]} (mono). Consider converting for optimal results."
      end
    end

    # Create a simple chunk-based audio stream processor
    # This can be used by concrete implementations to process audio in chunks
    #
    # @param chunk_size [Integer] Size of each audio chunk in bytes
    # @yield [chunk] Block called for each audio chunk
    # @yieldparam chunk [String] Audio chunk data
    def process_audio_stream(audio_data, chunk_size: 1024)
      return enum_for(:process_audio_stream, audio_data, chunk_size: chunk_size) unless block_given?

      offset = 0
      while offset < audio_data.length
        chunk = audio_data[offset, chunk_size]
        yield chunk
        offset += chunk_size
      end
    end

    protected

    # Trigger the audio received callback with encoded audio
    #
    # @param audio_bytes [String] Raw audio bytes from recording
    def trigger_audio_received(audio_bytes)
      return unless @on_audio_received_callback && audio_bytes

      begin
        encoded_audio = encode_audio(audio_bytes)
        @on_audio_received_callback.call(encoded_audio)
      rescue => e
        warn "Error processing received audio: #{e.message}" if $DEBUG
      end
    end

    private

    # Check if two audio formats match
    #
    # @param format1 [Hash] First format
    # @param format2 [Hash] Second format
    # @return [Boolean] True if formats are equivalent
    def formats_match?(format1, format2)
      %i[sample_rate channels format bit_depth].all? do |key|
        format1[key] == format2[key]
      end
    end
  end
end