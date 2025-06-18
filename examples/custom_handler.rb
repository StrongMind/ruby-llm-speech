#!/usr/bin/env ruby
# frozen_string_literal: true

# Custom Audio Handler Example
# This example shows how to create and use custom audio handlers

require_relative '../lib/ruby_llm_speech'

# Configure AWS credentials
RubyLLMSpeech.configure do |config|
  config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID'] || 'your_aws_access_key'
  config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || 'your_aws_secret_key'
  config.aws_region = ENV['AWS_REGION'] || 'us-east-1'
  config.default_voice = 'Matthew'
  config.log_level = Logger::INFO
end

# Example 1: Logging Audio Handler
# This handler logs all audio events with detailed information
class LoggingAudioHandler < RubyLLMSpeech::AudioHandler
  def initialize(log_file = nil)
    super()
    @log_file = log_file
    @audio_count = 0
    @transcript_count = 0
    
    setup_callbacks
    puts "🎧 LoggingAudioHandler initialized"
    puts "📝 Log file: #{@log_file || 'console only'}"
  end

  private

  def setup_callbacks
    on_audio_received do |audio_data, metadata|
      @audio_count += 1
      
      log_message = build_audio_log_message(audio_data, metadata)
      log_to_file(log_message) if @log_file
      puts log_message
    end

    on_transcript_received do |transcript, metadata|
      @transcript_count += 1
      
      log_message = build_transcript_log_message(transcript, metadata)
      log_to_file(log_message) if @log_file
      puts log_message
    end
  end

  def build_audio_log_message(audio_data, metadata)
    timestamp = Time.now.strftime("%H:%M:%S.%3N")
    size = audio_data.respond_to?(:length) ? audio_data.length : "unknown"
    
    message = "[#{timestamp}] 🎵 AUDIO ##{@audio_count}: #{size} bytes"
    
    if metadata && metadata.any?
      message += " | Metadata: #{metadata.inspect}"
    end
    
    message
  end

  def build_transcript_log_message(transcript, metadata)
    timestamp = Time.now.strftime("%H:%M:%S.%3N")
    confidence = metadata[:confidence] ? " (#{(metadata[:confidence] * 100).round(1)}%)" : ""
    
    message = "[#{timestamp}] 📝 TRANSCRIPT ##{@transcript_count}#{confidence}: \"#{transcript}\""
    
    if metadata && metadata.keys.length > 1
      other_metadata = metadata.reject { |k, _| k == :confidence }
      message += " | #{other_metadata.inspect}" if other_metadata.any?
    end
    
    message
  end

  def log_to_file(message)
    File.open(@log_file, 'a') do |f|
      f.puts message
    end
  rescue StandardError => e
    puts "⚠️  Failed to write to log file: #{e.message}"
  end

  public

  def get_stats
    {
      audio_events: @audio_count,
      transcript_events: @transcript_count,
      log_file: @log_file
    }
  end
end

# Example 2: Audio Buffer Handler
# This handler buffers audio data for processing
class AudioBufferHandler < RubyLLMSpeech::AudioHandler
  attr_reader :audio_buffer, :transcript_buffer

  def initialize(buffer_size: 10)
    super()
    @buffer_size = buffer_size
    @audio_buffer = []
    @transcript_buffer = []
    
    setup_callbacks
    puts "🗄️  AudioBufferHandler initialized (buffer size: #{@buffer_size})"
  end

  def get_recent_audio(count = 5)
    @audio_buffer.last(count)
  end

  def get_recent_transcripts(count = 5)
    @transcript_buffer.last(count)
  end

  def clear_buffers
    @audio_buffer.clear
    @transcript_buffer.clear
    puts "🧹 Buffers cleared"
  end

  private

  def setup_callbacks
    on_audio_received do |audio_data, metadata|
      audio_entry = {
        data: audio_data,
        metadata: metadata,
        timestamp: Time.now,
        size: audio_data.respond_to?(:length) ? audio_data.length : 0
      }
      
      add_to_buffer(@audio_buffer, audio_entry)
      puts "🎵 Audio buffered (#{@audio_buffer.length}/#{@buffer_size}): #{audio_entry[:size]} bytes"
    end

    on_transcript_received do |transcript, metadata|
      transcript_entry = {
        text: transcript,
        metadata: metadata,
        timestamp: Time.now,
        length: transcript.length
      }
      
      add_to_buffer(@transcript_buffer, transcript_entry)
      puts "📝 Transcript buffered (#{@transcript_buffer.length}/#{@buffer_size}): \"#{transcript}\""
    end
  end

  def add_to_buffer(buffer, entry)
    buffer << entry
    buffer.shift if buffer.length > @buffer_size
  end
end

# Example 3: Analytics Audio Handler
# This handler tracks analytics and patterns
class AnalyticsAudioHandler < RubyLLMSpeech::AudioHandler
  def initialize
    super()
    @start_time = Time.now
    @analytics = {
      total_audio_bytes: 0,
      total_transcripts: 0,
      average_transcript_length: 0,
      session_duration: 0,
      audio_events_per_minute: 0,
      transcript_events_per_minute: 0
    }
    
    setup_callbacks
    puts "📊 AnalyticsAudioHandler initialized"
  end

  def get_analytics
    update_analytics
    @analytics.dup
  end

  def print_analytics
    update_analytics
    
    puts "📊 Session Analytics"
    puts "=" * 30
    puts "Duration: #{@analytics[:session_duration].round(2)} seconds"
    puts "Total Audio: #{format_bytes(@analytics[:total_audio_bytes])}"
    puts "Total Transcripts: #{@analytics[:total_transcripts]}"
    puts "Avg Transcript Length: #{@analytics[:average_transcript_length].round(1)} chars"
    puts "Audio Events/min: #{@analytics[:audio_events_per_minute].round(1)}"
    puts "Transcript Events/min: #{@analytics[:transcript_events_per_minute].round(1)}"
    puts
  end

  private

  def setup_callbacks
    @audio_events = []
    @transcript_events = []

    on_audio_received do |audio_data, metadata|
      size = audio_data.respond_to?(:length) ? audio_data.length : 0
      
      @audio_events << {
        timestamp: Time.now,
        size: size,
        metadata: metadata
      }
      
      puts "📈 Audio event tracked: #{format_bytes(size)}"
    end

    on_transcript_received do |transcript, metadata|
      @transcript_events << {
        timestamp: Time.now,
        text: transcript,
        length: transcript.length,
        metadata: metadata
      }
      
      puts "📈 Transcript event tracked: #{transcript.length} chars"
    end
  end

  def update_analytics
    @analytics[:session_duration] = Time.now - @start_time
    @analytics[:total_audio_bytes] = @audio_events.sum { |event| event[:size] }
    @analytics[:total_transcripts] = @transcript_events.length
    
    if @transcript_events.any?
      total_length = @transcript_events.sum { |event| event[:length] }
      @analytics[:average_transcript_length] = total_length.to_f / @transcript_events.length
    end
    
    minutes = @analytics[:session_duration] / 60.0
    if minutes > 0
      @analytics[:audio_events_per_minute] = @audio_events.length / minutes
      @analytics[:transcript_events_per_minute] = @transcript_events.length / minutes
    end
  end

  def format_bytes(bytes)
    return "0 B" if bytes == 0
    
    units = ['B', 'KB', 'MB', 'GB']
    exp = (Math.log(bytes) / Math.log(1024)).floor
    exp = [exp, units.length - 1].min
    
    "#{(bytes.to_f / (1024 ** exp)).round(2)} #{units[exp]}"
  end
end

# Demo class that uses custom handlers
class CustomHandlerDemo
  include RubyLLMSpeech::ChatExtension

  def initialize
    puts "🎛️  Custom Audio Handler Demo"
    puts "=" * 40
  end

  def demo_logging_handler
    puts "1️⃣  Demo: Logging Audio Handler"
    
    log_file = "audio_log_#{Time.now.strftime('%Y%m%d_%H%M%S')}.log"
    handler = LoggingAudioHandler.new(log_file)
    
    configure_speech(
      voice: 'Joanna',
      audio_handler: handler,
      system_prompt: 'You are demonstrating logging capabilities.'
    )
    
    # Simulate some interactions
    speak("This is a test of the logging audio handler.")
    speak("Every audio event and transcript will be logged.")
    
    # Show stats
    stats = handler.get_stats
    puts "📊 Logging Stats: #{stats}"
    puts "📁 Log file created: #{log_file}"
    puts
  end

  def demo_buffer_handler
    puts "2️⃣  Demo: Audio Buffer Handler"
    
    handler = AudioBufferHandler.new(buffer_size: 5)
    
    configure_speech(
      voice: 'Amy',
      audio_handler: handler,
      system_prompt: 'You are demonstrating buffering capabilities.'
    )
    
    # Generate some events
    test_messages = [
      "First message for buffering",
      "Second message in the buffer",
      "Third message to test overflow",
      "Fourth message should push out the first",
      "Fifth message in our buffer demo"
    ]
    
    test_messages.each_with_index do |message, index|
      puts "Sending message #{index + 1}..."
      speak(message)
      sleep(0.5)
    end
    
    # Show buffer contents
    puts "📋 Recent Audio Events:"
    handler.get_recent_audio(3).each_with_index do |audio, i|
      puts "  #{i + 1}. #{audio[:timestamp].strftime('%H:%M:%S')} - #{audio[:size]} bytes"
    end
    
    puts "📋 Recent Transcripts:"
    handler.get_recent_transcripts(3).each_with_index do |transcript, i|
      puts "  #{i + 1}. #{transcript[:timestamp].strftime('%H:%M:%S')} - \"#{transcript[:text]}\""
    end
    puts
  end

  def demo_analytics_handler
    puts "3️⃣  Demo: Analytics Audio Handler"
    
    handler = AnalyticsAudioHandler.new
    
    configure_speech(
      voice: 'Matthew',
      audio_handler: handler,
      system_prompt: 'You are demonstrating analytics capabilities.'
    )
    
    # Generate analytics data
    analytics_messages = [
      "Starting analytics demo with first message",
      "This is the second message for analytics tracking",
      "Third message to build up some data",
      "Fourth message with more content for analysis",
      "Final message to complete our analytics demonstration"
    ]
    
    analytics_messages.each_with_index do |message, index|
      puts "Analytics message #{index + 1}..."
      speak(message)
      sleep(0.8) # Simulate realistic timing
    end
    
    # Show analytics
    handler.print_analytics
  end

  def demo_combined_handlers
    puts "4️⃣  Demo: Combined Handler Approach"
    
    # You could create a handler that combines multiple behaviors
    puts "💡 In practice, you might combine logging + analytics + buffering"
    puts "   into a single comprehensive handler for production use."
    puts
    
    # Example of handler composition
    log_handler = LoggingAudioHandler.new
    buffer_handler = AudioBufferHandler.new(buffer_size: 3)
    
    # Configure with one handler (in practice, you'd create a composite handler)
    configure_speech(
      voice: 'Joanna',
      audio_handler: log_handler,
      system_prompt: 'Demonstrating handler composition concepts.'
    )
    
    speak("This demonstrates how you might combine multiple handler behaviors.")
    
    puts "✅ Combined approach demonstrated"
    puts
  end

  def cleanup
    puts "🧹 Cleaning up demo..."
    close_voice_session
    puts "✅ Custom handler demo completed"
  end
end

# Main demo function
def main
  puts "🚀 Starting Custom Audio Handler Demo"
  puts

  begin
    demo = CustomHandlerDemo.new
    
    # Run all handler demos
    demo.demo_logging_handler
    demo.demo_buffer_handler
    demo.demo_analytics_handler
    demo.demo_combined_handlers
    
    puts "🎉 All custom handler demos completed successfully!"
    
  rescue RubyLLMSpeech::ConfigurationError => e
    puts "❌ Configuration Error: #{e.message}"
    puts "💡 Make sure to set your AWS credentials:"
    puts "   export AWS_ACCESS_KEY_ID='your_key'"
    puts "   export AWS_SECRET_ACCESS_KEY='your_secret'"
    puts "   export AWS_REGION='us-east-1'"
    
  rescue RubyLLMSpeech::Error => e
    puts "❌ Error: #{e.message}"
    
  ensure
    demo&.cleanup
  end
end

# Run the demo if this file is executed directly
main if __FILE__ == $PROGRAM_NAME