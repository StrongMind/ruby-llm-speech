# frozen_string_literal: true

require "logger"
require_relative "ruby_llm_speech/version"
require_relative "ruby_llm_speech/chat_extension"
require_relative "ruby_llm_speech/nova_sonic_client"
require_relative "ruby_llm_speech/audio_handler"
require_relative "ruby_llm_speech/conversation_transcript"
require_relative "ruby_llm_speech/example_tools"

module RubyLLMSpeech
  class Error < StandardError; end
  class ConnectionError < Error; end
  class AuthenticationError < Error; end
  class ModelError < Error; end
  class AudioError < Error; end
  class SessionError < Error; end
  class ConfigurationError < Error; end
  class ToolError < Error; end

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.logger
    @logger ||= Logger.new($stdout).tap do |logger|
      logger.level = Logger::INFO
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{severity} #{progname}: #{msg}\n"
      end
    end
  end

  def self.logger=(new_logger)
    @logger = new_logger
  end

  class Configuration
    attr_accessor :aws_access_key_id, :aws_secret_access_key, :aws_region, :default_voice
    attr_accessor :log_level, :error_retry_attempts, :connection_timeout

    def initialize
      @aws_region = "us-east-1"
      @default_voice = "Matthew"
      @log_level = Logger::INFO
      @error_retry_attempts = 3
      @connection_timeout = 30
    end
  end
end

# Extend RubyLLM::Chat to add speech capabilities
begin
  require "ruby_llm"
  RubyLLM::Chat.include(RubyLLMSpeech::ChatExtension)
rescue LoadError
  # ruby_llm not available - extension will be loaded when it becomes available
end