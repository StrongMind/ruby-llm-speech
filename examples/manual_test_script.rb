#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual test script for ruby-llm-speech gem
# This script can be used to validate the gem with real AWS connections

require "ruby_llm_speech"

class ManualTestScript
  def initialize
    @test_results = []
    @config_valid = false
  end

  def run
    puts "=" * 60
    puts "Ruby LLM Speech Manual Test Script"
    puts "=" * 60
    puts

    check_environment
    test_configuration
    test_basic_functionality if @config_valid
    test_audio_functionality if @config_valid
    test_error_handling

    print_results
  end

  private

  def check_environment
    test("Environment Variables Check") do
      required_vars = %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION]
      missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }

      if missing_vars.any?
        puts "  Missing environment variables: #{missing_vars.join(', ')}"
        puts "  Please set these before running the test:"
        missing_vars.each do |var|
          puts "    export #{var}=your_value_here"
        end
        false
      else
        puts "  All required environment variables are set"
        true
      end
    end
  end

  def test_configuration
    test("Configuration Setup") do
      RubyLLMSpeech.configure do |config|
        config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
        config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
        config.aws_region = ENV['AWS_REGION']
        config.voice_id = 'default'
      end

      # Test configuration validation
      RubyLLMSpeech.configuration.validate!
      
      puts "  Configuration validated successfully"
      puts "  Region: #{RubyLLMSpeech.configuration.aws_region}"
      puts "  Voice ID: #{RubyLLMSpeech.configuration.voice_id}"
      puts "  Model ID: #{RubyLLMSpeech.configuration.model_id}"
      
      @config_valid = true
      true
    rescue RubyLLMSpeech::Error => e
      puts "  Configuration error: #{e.message}"
      false
    end
  end

  def test_basic_functionality
    test("Basic Functionality") do
      # Test creating a Nova Sonic client
      client = RubyLLMSpeech::NovaSonicClient.new
      puts "  ✓ Created Nova Sonic client"

      # Test event handler
      event_handler = RubyLLMSpeech::EventHandler.new
      puts "  ✓ Created event handler"

      # Test audio handler interface
      audio_handler = RubyLLMSpeech::AudioHandler.new
      puts "  ✓ Created audio handler interface"

      true
    rescue => e
      puts "  Error: #{e.message}"
      false
    end
  end

  def test_audio_functionality
    test("Audio Functionality") do
      handler = RubyLLMSpeech::AudioHandler.new

      # Test audio encoding/decoding
      test_audio = "test audio data"
      encoded = handler.encode_audio(test_audio)
      decoded = handler.decode_audio(encoded)

      if decoded == test_audio
        puts "  ✓ Audio encoding/decoding works correctly"
      else
        puts "  ✗ Audio encoding/decoding failed"
        return false
      end

      # Test format validation
      begin
        handler.validate_audio_format("audio/pcm")
        puts "  ✓ Audio format validation works"
      rescue => e
        puts "  ✗ Audio format validation failed: #{e.message}"
        return false
      end

      # Test recommended configuration
      config = RubyLLMSpeech::AudioHandler.recommended_config
      puts "  ✓ Recommended audio config: #{config}"

      true
    rescue => e
      puts "  Error: #{e.message}"
      false
    end
  end

  def test_error_handling
    test("Error Handling") do
      # Test configuration validation errors
      begin
        bad_config = RubyLLMSpeech::Configuration.new
        bad_config.validate!
        puts "  ✗ Configuration validation should have failed"
        false
      rescue RubyLLMSpeech::Error
        puts "  ✓ Configuration validation correctly raises errors"
      end

      # Test audio format validation errors
      begin
        handler = RubyLLMSpeech::AudioHandler.new
        handler.validate_audio_format("invalid/format")
        puts "  ✗ Audio format validation should have failed"
        false
      rescue RubyLLMSpeech::Error
        puts "  ✓ Audio format validation correctly raises errors"
      end

      # Test invalid base64 decoding
      begin
        handler = RubyLLMSpeech::AudioHandler.new
        handler.decode_audio("invalid base64!")
        puts "  ✗ Base64 decoding should have failed"
        false
      rescue RubyLLMSpeech::Error
        puts "  ✓ Base64 decoding correctly raises errors"
      end

      true
    rescue => e
      puts "  Unexpected error: #{e.message}"
      false
    end
  end

  def test_nova_sonic_integration
    test("Nova Sonic Integration (requires AWS access)") do
      puts "  Warning: This test requires valid AWS credentials and will make real API calls"
      print "  Continue? (y/N): "
      
      response = gets.chomp.downcase
      return true unless response == 'y'

      client = RubyLLMSpeech::NovaSonicClient.new
      
      # Set up a simple event handler
      received_events = []
      
      # Start a session (this will make a real AWS call)
      session_id = client.start_session(
        system_prompt: "You are a test assistant. Respond with just 'Hello test' and nothing else."
      ) do |event_type, data|
        received_events << [event_type, data]
        puts "    Received event: #{event_type}"
      end

      puts "  ✓ Started Nova Sonic session: #{session_id}"
      
      # Send a simple text message
      client.send_text("Hello")
      puts "  ✓ Sent text message"
      
      # Wait for responses
      sleep(5)
      
      # Stop the session
      client.stop_session
      puts "  ✓ Stopped session"
      
      puts "  ✓ Received #{received_events.length} events"
      
      true
    rescue => e
      puts "  Error: #{e.message}"
      puts "  This might be due to:"
      puts "    - Invalid AWS credentials"
      puts "    - Insufficient permissions"
      puts "    - Network connectivity issues"
      puts "    - Nova Sonic not available in your region"
      false
    end
  end

  def test_ruby_llm_integration
    test("RubyLLM Integration") do
      begin
        require "ruby_llm"
        puts "  ✓ RubyLLM gem is available"
        
        # Check if our extensions are properly loaded
        if defined?(RubyLLM::Chat)
          chat = RubyLLM.chat
          
          # Check if our speech methods are available
          speech_methods = %i[speak send_audio on_audio_received speech_active? stop_speech]
          available_methods = speech_methods.select { |method| chat.respond_to?(method) }
          
          puts "  ✓ Available speech methods: #{available_methods.join(', ')}"
          
          if available_methods.length == speech_methods.length
            puts "  ✓ All speech methods are available"
            true
          else
            missing = speech_methods - available_methods
            puts "  ✗ Missing speech methods: #{missing.join(', ')}"
            false
          end
        else
          puts "  ✗ RubyLLM::Chat class not available"
          false
        end
      rescue LoadError
        puts "  RubyLLM gem not available - speech extensions won't be loaded"
        puts "  Install with: gem install ruby_llm"
        true # This is not a failure for the gem itself
      end
    rescue => e
      puts "  Error: #{e.message}"
      false
    end
  end

  def test(description)
    print "#{description}... "
    result = yield
    @test_results << [description, result]
    puts result ? "✓ PASSED" : "✗ FAILED"
    puts
    result
  end

  def print_results
    puts "=" * 60
    puts "Test Results Summary"
    puts "=" * 60

    passed = @test_results.count { |_, result| result }
    total = @test_results.length

    @test_results.each do |description, result|
      status = result ? "✓ PASS" : "✗ FAIL"
      puts "#{status}: #{description}"
    end

    puts
    puts "Total: #{passed}/#{total} tests passed"
    
    if passed == total
      puts "🎉 All tests passed!"
    else
      puts "⚠️  Some tests failed. Check the output above for details."
    end
    
    puts
    puts "Next steps:"
    if @config_valid
      puts "1. Try the basic_speech_example.rb for a complete demo"
      puts "2. Implement a concrete AudioHandler for your platform"
      puts "3. Test with real voice conversations"
    else
      puts "1. Fix configuration issues first"
      puts "2. Ensure AWS credentials are properly set"
      puts "3. Verify Nova Sonic is available in your region"
    end
  end
end

# Run the manual test
if __FILE__ == $0
  ManualTestScript.new.run
end