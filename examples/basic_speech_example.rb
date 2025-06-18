#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic example of using ruby-llm-speech for voice conversations
# This example shows the suggested interface from the prompt

require "ruby_llm_speech"

# Configure the gem with AWS credentials
RubyLLMSpeech.configure do |config|
  config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.aws_region = ENV['AWS_REGION'] || 'us-east-1'
  config.voice_id = 'default' # or specific Nova Sonic voice
end

# Example Time tool for demonstration
class Time < RubyLLM::Tool
  description "Gets the current time"

  def execute
    Time.current.strftime("%H:%M:%S")
  end
end

# Set up RubyLLM chat with Nova Sonic
chat = RubyLLM.chat
  .with_model("amazon.nova-sonic-v1:0") 
  .with_tool(Time)
  .with_instructions("You are a friend who is ready to speak with the user audibly.")

# AudioHandler is a made up class that is not part of the gem, 
# but could be included in a sample console app that uses FFI::PortAudio
handler = AudioHandler.new 

# Set up audio input handler
handler.on_audio_received do |audio_data|
  # Send recorded audio from the user to the model
  chat.send_audio(audio_data)
end

# Set up audio output handler
chat.on_audio_received do |audio|
  # Play the audio received from the model back to the user
  handler.play_audio(audio)
end

# Start the conversation and print the transcript of the conversation
puts "Starting speech conversation..."
puts "Speak into your microphone to interact with the AI."
puts "Text transcript will appear below:"
puts "-" * 50

begin
  session_id = chat.speak do |chunk|
    # Print text transcript as the AI responds
    print chunk.content
  end
  
  puts "\nSpeech session started with ID: #{session_id}"
  
  # Start audio recording (this would be implemented in the AudioHandler)
  handler.start_recording
  
  # Keep the conversation going until interrupted
  loop do
    sleep(0.1)
    
    # Check if user wants to interrupt the AI
    if handler.user_wants_to_interrupt?
      chat.interrupt_speech
    end
    
    # Exit on some condition (user input, timeout, etc.)
    break if handler.should_exit?
  end
  
rescue KeyboardInterrupt
  puts "\n\nStopping speech conversation..."
  chat.stop_speech
  handler.stop_recording
end

puts "Speech conversation ended."