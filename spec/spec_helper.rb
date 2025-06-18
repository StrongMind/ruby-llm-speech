# frozen_string_literal: true

require "bundler/setup"
require "ruby_llm_speech"
require "webmock/rspec"
require "rspec"

# Configure WebMock to allow real connections for specific hosts if needed
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset configuration between tests
  config.before(:each) do
    RubyLLMSpeech.reset_configuration!
  end

  # Set up WebMock stubs for AWS Bedrock
  config.before(:each) do
    # Mock AWS STS calls if needed
    stub_request(:post, /sts\.amazonaws\.com/)
      .to_return(status: 200, body: "", headers: {})

    # Mock AWS Bedrock bidirectional streaming
    stub_request(:post, /bedrock-runtime\..*\.amazonaws\.com.*invoke-with-bidirectional-stream/)
      .to_return(status: 200, body: mock_bedrock_response, headers: {
        "Content-Type" => "application/x-amz-json-1.1"
      })
  end

  # Mock a basic Bedrock streaming response
  def mock_bedrock_response
    JSON.generate({
      event: {
        contentStart: {
          role: "assistant"
        }
      }
    })
  end

  # Helper to create test configuration
  def test_configuration
    RubyLLMSpeech::Configuration.new(
      aws_access_key_id: "test_key",
      aws_secret_access_key: "test_secret",
      aws_region: "us-east-1"
    )
  end

  # Helper to create mock audio data
  def mock_audio_data
    Base64.strict_encode64("mock audio bytes")
  end

  # Helper to create mock RubyLLM::Chat instance
  def mock_chat
    chat = double("RubyLLM::Chat")
    allow(chat).to receive(:instance_variable_get).with(:@model).and_return("amazon.nova-sonic-v1:0")
    allow(chat).to receive(:instance_variable_get).with(:@tools).and_return([])
    chat
  end
end