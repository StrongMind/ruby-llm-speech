#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple Voice Chat Example
# This example shows basic voice interaction with Nova Sonic

require_relative '../lib/ruby_llm_speech'

# Configure AWS credentials (you'll need to set these environment variables)
RubyLLMSpeech.configure do |config|
  config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID'] || 'your_aws_access_key'
  config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || 'your_aws_secret_key'
  config.aws_region = ENV['AWS_REGION'] || 'us-east-1'
  config.default_voice = 'Matthew'
  config.log_level = Logger::INFO
end

# Create a simple chat class that includes speech capabilities
class SimpleVoiceChat
  include RubyLLMSpeech::ChatExtension

  def initialize
    puts "🎤 Simple Voice Chat Example"
    puts "=" * 40
    
    # Configure speech with a friendly voice
    configure_speech(
      voice: 'Joanna',
      temperature: 0.7,
      system_prompt: 'You are a friendly voice assistant. Keep responses conversational and helpful.',
      transcript_enabled: true
    )
    
    puts "✅ Voice chat configured successfully!"
    puts "📋 Session ID: #{session_id}"
    puts "🔊 Voice: Joanna"
    puts "📝 Transcript: Enabled"
    puts
  end

  def demo_text_to_speech
    puts "🗣️  Demo: Text to Speech"
    puts "Sending: 'Hello! Welcome to Ruby LLM Speech. How are you today?'"
    
    speak("Hello! Welcome to Ruby LLM Speech. How are you today?")
    
    puts "✅ Text sent to Nova Sonic for speech synthesis"
    puts
  end

  def demo_conversation
    puts "💬 Demo: Conversation"
    
    messages = [
      "Tell me a fun fact about Ruby programming language",
      "What's the weather like conceptually?",
      "Can you help me understand what you can do?"
    ]
    
    messages.each_with_index do |message, index|
      puts "#{index + 1}. User: #{message}"
      speak(message)
      puts "   ✅ Sent to Nova Sonic"
      sleep(1) # Simulate processing time
    end
    puts
  end

  def show_transcript
    puts "📋 Conversation Transcript:"
    puts "=" * 40
    
    transcript_text = get_transcript(format: :text, include_timestamps: true)
    if transcript_text && !transcript_text.empty?
      puts transcript_text
    else
      puts "No transcript available yet."
    end
    puts
    
    # Show summary
    summary = get_transcript(format: :summary)
    if summary
      puts "📊 Conversation Summary:"
      puts "  Total messages: #{summary[:total_messages]}"
      puts "  Duration: #{summary[:duration].round(2)} seconds"
      puts "  Session ID: #{summary[:session_id]}"
    end
    puts
  end

  def demo_session_recovery
    puts "🔄 Demo: Session Recovery"
    old_session_id = session_id
    puts "Current session: #{old_session_id}"
    
    # Simulate session recovery
    new_session_id = "recovered_#{Time.now.to_i}"
    puts "Recovering session: #{new_session_id}"
    
    begin
      recover_session(new_session_id)
      puts "✅ Session recovery initiated"
      puts "New session ID: #{session_id}"
    rescue RubyLLMSpeech::SessionError => e
      puts "⚠️  Session recovery failed: #{e.message}"
      puts "This is expected in demo mode - no existing session to recover"
    end
    puts
  end

  def cleanup
    puts "🧹 Cleaning up..."
    close_voice_session
    puts "✅ Voice session closed"
  end
end

# Run the demo
def main
  puts "🚀 Starting Simple Voice Chat Demo"
  puts
  
  begin
    chat = SimpleVoiceChat.new
    
    # Run demos
    chat.demo_text_to_speech
    chat.demo_conversation
    chat.show_transcript
    chat.demo_session_recovery
    
    puts "🎉 Demo completed successfully!"
    
  rescue RubyLLMSpeech::ConfigurationError => e
    puts "❌ Configuration Error: #{e.message}"
    puts "💡 Make sure to set your AWS credentials:"
    puts "   export AWS_ACCESS_KEY_ID='your_key'"
    puts "   export AWS_SECRET_ACCESS_KEY='your_secret'"
    puts "   export AWS_REGION='us-east-1'"
    
  rescue RubyLLMSpeech::Error => e
    puts "❌ Error: #{e.message}"
    
  ensure
    chat&.cleanup
  end
end

# Run the demo if this file is executed directly
main if __FILE__ == $PROGRAM_NAME