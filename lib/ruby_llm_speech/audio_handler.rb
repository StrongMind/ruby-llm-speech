# frozen_string_literal: true

module RubyLLMSpeech
  class AudioHandler
    attr_reader :audio_received_callbacks, :transcript_received_callbacks

    def initialize
      @audio_received_callbacks = []
      @transcript_received_callbacks = []
    end

    def on_audio_received(&block)
      @audio_received_callbacks << block if block_given?
      self
    end

    def on_transcript_received(&block)
      @transcript_received_callbacks << block if block_given?
      self
    end

    def handle_audio_received(audio_data, metadata = {})
      @audio_received_callbacks.each { |callback| callback.call(audio_data, metadata) }
    end

    def handle_transcript_received(transcript, metadata = {})
      @transcript_received_callbacks.each { |callback| callback.call(transcript, metadata) }
    end

    def record_audio
      raise NotImplementedError, "Subclasses must implement #record_audio"
    end

    def stop_recording
      raise NotImplementedError, "Subclasses must implement #stop_recording"
    end

    def play_audio(audio_data)
      raise NotImplementedError, "Subclasses must implement #play_audio"
    end

    def stop_playback
      raise NotImplementedError, "Subclasses must implement #stop_playback"
    end

    def validate_audio_format(audio_data)
      raise NotImplementedError, "Subclasses must implement #validate_audio_format"
    end
  end

  class DefaultAudioHandler < AudioHandler
    def initialize
      super
      @recording = false
      @playing = false
    end

    def record_audio
      @recording = true
      # Default implementation - users should override this
      # This is just a placeholder that returns empty audio data
      []
    end

    def stop_recording
      @recording = false
    end

    def play_audio(audio_data)
      @playing = true
      # Default implementation - users should override this
      # This is just a placeholder that doesn't actually play audio
      handle_audio_received(audio_data, { format: "pcm", sample_rate: 16000 })
    end

    def stop_playback
      @playing = false
    end

    def validate_audio_format(audio_data)
      # Default validation - accepts any audio data
      # Users should override this to validate their specific format
      return true if audio_data.is_a?(Array) || audio_data.is_a?(String)

      false
    end

    def recording?
      @recording
    end

    def playing?
      @playing
    end
  end

  # Example of a more sophisticated audio handler implementation
  class ExampleAudioHandler < AudioHandler
    def initialize(input_device: nil, output_device: nil, sample_rate: 16000)
      super()
      @input_device = input_device
      @output_device = output_device
      @sample_rate = sample_rate
      @audio_buffer = []
    end

    def record_audio
      # Example implementation - in real usage this would interface with
      # actual audio recording libraries like portaudio, alsa, etc.
      puts "🎙️  Starting audio recording..."
      @recording = true
      
      # Simulate recording by collecting audio data
      Thread.new do
        while @recording
          # In real implementation, this would capture audio from microphone
          audio_chunk = simulate_audio_input
          @audio_buffer << audio_chunk
          sleep(0.1)
        end
      end
    end

    def stop_recording
      puts "🛑 Stopping audio recording..."
      @recording = false
      audio_data = @audio_buffer.dup
      @audio_buffer.clear
      audio_data
    end

    def play_audio(audio_data)
      puts "🔊 Playing audio response..."
      @playing = true
      
      # In real implementation, this would play audio through speakers
      # For now, we'll just simulate playback and trigger the callback
      Thread.new do
        # Simulate playback duration
        sleep(audio_data.length * 0.1) if audio_data.respond_to?(:length)
        
        handle_audio_received(audio_data, {
          format: "pcm",
          sample_rate: @sample_rate,
          channels: 1
        })
        
        @playing = false
        puts "✅ Audio playback completed"
      end
    end

    def stop_playback
      puts "⏹️  Stopping audio playback..."
      @playing = false
    end

    def validate_audio_format(audio_data)
      # Validate that audio data meets Nova Sonic requirements
      return false unless audio_data.is_a?(Array) || audio_data.is_a?(String)
      return false if audio_data.empty?

      # Add more specific validation for PCM format, sample rate, etc.
      true
    end

    private

    def simulate_audio_input
      # Simulate audio input - in real usage this would be actual audio data
      Array.new(1600) { rand(-32768..32767) } # 16-bit PCM data
    end
  end
end