#!/usr/bin/env ruby
# frozen_string_literal: true

# Example AudioHandler implementation using FFI::PortAudio
# This shows how to create a concrete audio handler that works with ruby-llm-speech

require "ruby_llm_speech"
require "ffi/portaudio" # This would need to be installed separately

# Concrete implementation of AudioHandler using PortAudio
class AudioHandler < RubyLLMSpeech::AudioHandler
  SAMPLE_RATE = 16_000
  FRAMES_PER_BUFFER = 1024
  CHANNELS = 1

  def initialize
    super
    @input_stream = nil
    @output_stream = nil
    @audio_buffer = []
    @recording_thread = nil
    
    # Initialize PortAudio
    FFI::PortAudio.init
    
    setup_input_stream
    setup_output_stream
  end

  # Start recording audio from microphone
  def start_recording
    return if recording?
    
    super # Sets @recording = true
    
    # Start the input stream
    FFI::PortAudio.start_stream(@input_stream)
    
    # Start recording in a background thread
    @recording_thread = Thread.new do
      record_audio_loop
    end
    
    puts "Started recording audio..."
  end

  # Stop recording audio
  def stop_recording
    return unless recording?
    
    super # Sets @recording = false
    
    # Stop the input stream
    FFI::PortAudio.stop_stream(@input_stream) if @input_stream
    
    # Wait for recording thread to finish
    @recording_thread&.join
    @recording_thread = nil
    
    puts "Stopped recording audio."
  end

  # Play audio data through speakers
  def play(audio_data)
    super(audio_data) do
      # Convert audio data to the format expected by PortAudio
      samples = convert_to_samples(audio_data)
      
      # Write samples to the output stream
      FFI::PortAudio.write_stream(@output_stream, samples, samples.length / CHANNELS)
    end
  end

  # Check if user wants to interrupt (simple implementation)
  def user_wants_to_interrupt?
    # In a real implementation, this might check for:
    # - Voice activity detection during AI speech
    # - Keyboard input
    # - UI button presses
    false
  end

  # Check if we should exit the conversation
  def should_exit?
    # In a real implementation, this might check for:
    # - Specific voice commands ("goodbye", "exit")
    # - UI interactions
    # - Timeout conditions
    false
  end

  # Clean up resources
  def cleanup
    stop_recording if recording?
    
    FFI::PortAudio.close_stream(@input_stream) if @input_stream
    FFI::PortAudio.close_stream(@output_stream) if @output_stream
    FFI::PortAudio.terminate
  end

  private

  # Set up PortAudio input stream for recording
  def setup_input_stream
    input_params = FFI::PortAudio::StreamParameters.new(
      device: FFI::PortAudio.default_input_device,
      channel_count: CHANNELS,
      sample_format: :float32,
      suggested_latency: 0.1
    )

    @input_stream = FFI::PortAudio.open_stream(
      input_parameters: input_params,
      output_parameters: nil,
      sample_rate: SAMPLE_RATE,
      frames_per_buffer: FRAMES_PER_BUFFER
    )
  end

  # Set up PortAudio output stream for playback
  def setup_output_stream
    output_params = FFI::PortAudio::StreamParameters.new(
      device: FFI::PortAudio.default_output_device,
      channel_count: CHANNELS,
      sample_format: :float32,
      suggested_latency: 0.1
    )

    @output_stream = FFI::PortAudio.open_stream(
      input_parameters: nil,
      output_parameters: output_params,
      sample_rate: SAMPLE_RATE,
      frames_per_buffer: FRAMES_PER_BUFFER
    )

    FFI::PortAudio.start_stream(@output_stream)
  end

  # Main recording loop
  def record_audio_loop
    while recording?
      begin
        # Read audio data from input stream
        buffer = Array.new(FRAMES_PER_BUFFER * CHANNELS, 0.0)
        frames_read = FFI::PortAudio.read_stream(@input_stream, buffer, FRAMES_PER_BUFFER)
        
        if frames_read > 0
          # Convert float samples to PCM bytes
          audio_bytes = convert_to_pcm_bytes(buffer[0, frames_read * CHANNELS])
          
          # Trigger the callback with encoded audio
          trigger_audio_received(audio_bytes)
        end
        
        sleep(0.01) # Small sleep to prevent busy waiting
      rescue => e
        puts "Error in recording loop: #{e.message}"
        break
      end
    end
  end

  # Convert float samples to PCM bytes
  def convert_to_pcm_bytes(float_samples)
    # Convert float32 samples (-1.0 to 1.0) to 16-bit PCM
    pcm_samples = float_samples.map do |sample|
      # Clamp sample to valid range
      sample = [[-1.0, sample].max, 1.0].min
      
      # Convert to 16-bit integer
      (sample * 32767).round
    end
    
    # Pack as little-endian 16-bit integers
    pcm_samples.pack("s<*")
  end

  # Convert PCM bytes to float samples for playback
  def convert_to_samples(audio_data)
    # Unpack 16-bit PCM data
    pcm_samples = audio_data.unpack("s<*")
    
    # Convert to float32 samples (-1.0 to 1.0)
    pcm_samples.map { |sample| sample / 32767.0 }
  end
end

# Usage example with the concrete AudioHandler
if __FILE__ == $0
  puts "AudioHandler Example"
  puts "This demonstrates a concrete audio handler implementation."
  puts "Note: This requires ffi-portaudio gem to be installed."
  
  begin
    handler = AudioHandler.new
    
    # Test basic functionality
    puts "Testing audio recording for 3 seconds..."
    
    handler.on_audio_received do |audio_data|
      puts "Received #{audio_data.length} bytes of encoded audio"
    end
    
    handler.start_recording
    sleep(3)
    handler.stop_recording
    
    puts "Audio recording test complete."
    
    # Test audio playback
    puts "Testing audio playback..."
    
    # Generate a simple tone for testing
    duration = 1.0 # seconds
    frequency = 440.0 # A4 note
    sample_rate = 16_000
    samples = (0...duration * sample_rate).map do |i|
      Math.sin(2 * Math::PI * frequency * i / sample_rate)
    end
    
    # Convert to PCM bytes
    pcm_samples = samples.map { |sample| (sample * 32767).round }
    audio_data = pcm_samples.pack("s<*")
    
    handler.play(audio_data)
    puts "Audio playback test complete."
    
  rescue LoadError
    puts "ffi-portaudio gem not available. Install with:"
    puts "gem install ffi-portaudio"
  rescue => e
    puts "Error: #{e.message}"
  ensure
    handler&.cleanup
  end
end