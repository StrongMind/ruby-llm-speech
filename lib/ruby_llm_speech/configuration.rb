# frozen_string_literal: true

module RubyLLMSpeech
  # Configuration class for RubyLLM Speech
  # Follows the same pattern as RubyLLM for explicit configuration
  class Configuration
    # AWS configuration
    attr_accessor :aws_access_key_id, :aws_secret_access_key, :aws_session_token, :aws_region

    # Nova Sonic specific configuration
    attr_accessor :voice_id, :model_id

    # Streaming and timeout configuration
    attr_accessor :request_timeout, :max_retries, :retry_interval

    # Audio configuration
    attr_accessor :audio_sample_rate, :audio_format, :audio_channels

    # @param options [Hash] Initial configuration options
    def initialize(options = {})
      # AWS defaults
      @aws_access_key_id = options[:aws_access_key_id]
      @aws_secret_access_key = options[:aws_secret_access_key]
      @aws_session_token = options[:aws_session_token]
      @aws_region = options[:aws_region] || "us-east-1"

      # Nova Sonic defaults
      @voice_id = options[:voice_id] || "default"
      @model_id = options[:model_id] || "amazon.nova-sonic-v1:0"

      # Streaming defaults
      @request_timeout = options[:request_timeout] || 300
      @max_retries = options[:max_retries] || 3
      @retry_interval = options[:retry_interval] || 1

      # Audio defaults (based on Nova Sonic documentation)
      @audio_sample_rate = options[:audio_sample_rate] || 16_000
      @audio_format = options[:audio_format] || "pcm"
      @audio_channels = options[:audio_channels] || 1
    end

    # Validate required configuration
    #
    # @raise [Error] If required configuration is missing
    def validate!
      missing = []
      missing << "aws_access_key_id" if aws_access_key_id.nil? || aws_access_key_id.empty?
      missing << "aws_secret_access_key" if aws_secret_access_key.nil? || aws_secret_access_key.empty?
      missing << "aws_region" if aws_region.nil? || aws_region.empty?

      unless missing.empty?
        raise Error, "Missing required configuration: #{missing.join(', ')}"
      end
    end

    # Get AWS credentials as a hash for the SDK
    #
    # @return [Hash] AWS credentials hash
    def aws_credentials
      validate!
      
      credentials = {
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key,
        region: aws_region
      }
      
      credentials[:session_token] = aws_session_token if aws_session_token
      credentials
    end

    # Get inference configuration for Nova Sonic
    #
    # @return [Hash] Inference configuration
    def inference_config
      {
        maxTokens: 1024,
        topP: 0.9,
        temperature: 0.7
      }
    end

    # Convert configuration to hash
    #
    # @return [Hash] Configuration as hash
    def to_h
      {
        aws_access_key_id: aws_access_key_id,
        aws_secret_access_key: aws_secret_access_key ? "[REDACTED]" : nil,
        aws_session_token: aws_session_token ? "[REDACTED]" : nil,
        aws_region: aws_region,
        voice_id: voice_id,
        model_id: model_id,
        request_timeout: request_timeout,
        max_retries: max_retries,
        retry_interval: retry_interval,
        audio_sample_rate: audio_sample_rate,
        audio_format: audio_format,
        audio_channels: audio_channels
      }
    end

    # String representation with sensitive data redacted
    #
    # @return [String] Configuration string
    def inspect
      "#<#{self.class.name}:#{object_id} #{to_h}>"
    end
  end
end