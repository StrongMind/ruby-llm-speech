# frozen_string_literal: true

require_relative "ruby_llm_speech/version"
require_relative "ruby_llm_speech/configuration"
require_relative "ruby_llm_speech/audio_handler"
require_relative "ruby_llm_speech/nova_sonic_client"
require_relative "ruby_llm_speech/event_handler"
require_relative "ruby_llm_speech/chat_extensions"

# Main module for RubyLLM Speech functionality
module RubyLLMSpeech
  class Error < StandardError; end

  class << self
    attr_writer :configuration

    # Get or create configuration instance
    #
    # @return [Configuration] The current configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the gem with a block
    #
    # @yield [config] Block that receives the configuration object
    # @yieldparam config [Configuration] The configuration object to modify
    # @example
    #   RubyLLMSpeech.configure do |config|
    #     config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
    #     config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
    #     config.aws_region = ENV['AWS_REGION']
    #   end
    def configure
      yield(configuration)
    end

    # Reset configuration to defaults
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

# Automatically extend RubyLLM::Chat when RubyLLM is loaded
begin
  require "ruby_llm"
  
  # Only extend if RubyLLM is available and Chat class exists
  if defined?(RubyLLM::Chat)
    RubyLLM::Chat.prepend(RubyLLMSpeech::ChatExtensions)
  end
rescue LoadError => e
  # RubyLLM not available, but that's okay for testing
  warn "RubyLLM not available: #{e.message}" if $DEBUG
end