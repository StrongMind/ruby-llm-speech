# frozen_string_literal: true

RSpec.describe RubyLLMSpeech::Configuration do
  describe "#initialize" do
    it "sets default values" do
      config = described_class.new

      expect(config.aws_region).to eq("us-east-1")
      expect(config.voice_id).to eq("default")
      expect(config.model_id).to eq("amazon.nova-sonic-v1:0")
      expect(config.request_timeout).to eq(300)
      expect(config.max_retries).to eq(3)
      expect(config.retry_interval).to eq(1)
      expect(config.audio_sample_rate).to eq(16_000)
      expect(config.audio_format).to eq("pcm")
      expect(config.audio_channels).to eq(1)
    end

    it "accepts custom options" do
      options = {
        aws_access_key_id: "custom_key",
        aws_secret_access_key: "custom_secret",
        aws_region: "us-west-2",
        voice_id: "custom_voice",
        model_id: "custom_model",
        request_timeout: 600
      }

      config = described_class.new(options)

      expect(config.aws_access_key_id).to eq("custom_key")
      expect(config.aws_secret_access_key).to eq("custom_secret")
      expect(config.aws_region).to eq("us-west-2")
      expect(config.voice_id).to eq("custom_voice")
      expect(config.model_id).to eq("custom_model")
      expect(config.request_timeout).to eq(600)
    end
  end

  describe "#validate!" do
    it "raises error when aws_access_key_id is missing" do
      config = described_class.new(
        aws_secret_access_key: "secret",
        aws_region: "us-east-1"
      )

      expect { config.validate! }.to raise_error(
        RubyLLMSpeech::Error,
        "Missing required configuration: aws_access_key_id"
      )
    end

    it "raises error when aws_secret_access_key is missing" do
      config = described_class.new(
        aws_access_key_id: "key",
        aws_region: "us-east-1"
      )

      expect { config.validate! }.to raise_error(
        RubyLLMSpeech::Error,
        "Missing required configuration: aws_secret_access_key"
      )
    end

    it "raises error when aws_region is missing" do
      config = described_class.new(
        aws_access_key_id: "key",
        aws_secret_access_key: "secret",
        aws_region: ""
      )

      expect { config.validate! }.to raise_error(
        RubyLLMSpeech::Error,
        "Missing required configuration: aws_region"
      )
    end

    it "raises error for multiple missing fields" do
      config = described_class.new

      expect { config.validate! }.to raise_error(
        RubyLLMSpeech::Error,
        /Missing required configuration: aws_access_key_id, aws_secret_access_key/
      )
    end

    it "does not raise error when all required fields are present" do
      config = described_class.new(
        aws_access_key_id: "key",
        aws_secret_access_key: "secret",
        aws_region: "us-east-1"
      )

      expect { config.validate! }.not_to raise_error
    end
  end

  describe "#aws_credentials" do
    it "returns credentials hash without session token" do
      config = described_class.new(
        aws_access_key_id: "key",
        aws_secret_access_key: "secret",
        aws_region: "us-west-2"
      )

      credentials = config.aws_credentials

      expect(credentials).to eq({
        access_key_id: "key",
        secret_access_key: "secret",
        region: "us-west-2"
      })
    end

    it "includes session token when present" do
      config = described_class.new(
        aws_access_key_id: "key",
        aws_secret_access_key: "secret",
        aws_region: "us-west-2",
        aws_session_token: "token"
      )

      credentials = config.aws_credentials

      expect(credentials).to eq({
        access_key_id: "key",
        secret_access_key: "secret",
        region: "us-west-2",
        session_token: "token"
      })
    end

    it "validates configuration before returning credentials" do
      config = described_class.new

      expect { config.aws_credentials }.to raise_error(RubyLLMSpeech::Error)
    end
  end

  describe "#inference_config" do
    it "returns default inference configuration" do
      config = described_class.new

      inference_config = config.inference_config

      expect(inference_config).to eq({
        maxTokens: 1024,
        topP: 0.9,
        temperature: 0.7
      })
    end
  end

  describe "#to_h" do
    it "returns configuration as hash with sensitive data redacted" do
      config = described_class.new(
        aws_access_key_id: "key",
        aws_secret_access_key: "secret",
        aws_session_token: "token",
        aws_region: "us-east-1"
      )

      hash = config.to_h

      expect(hash[:aws_access_key_id]).to eq("key")
      expect(hash[:aws_secret_access_key]).to eq("[REDACTED]")
      expect(hash[:aws_session_token]).to eq("[REDACTED]")
      expect(hash[:aws_region]).to eq("us-east-1")
    end

    it "shows nil for missing sensitive fields" do
      config = described_class.new(aws_access_key_id: "key")

      hash = config.to_h

      expect(hash[:aws_secret_access_key]).to be_nil
      expect(hash[:aws_session_token]).to be_nil
    end
  end

  describe "#inspect" do
    it "includes class name and configuration hash" do
      config = described_class.new(aws_access_key_id: "key")

      inspect_str = config.inspect

      expect(inspect_str).to include("RubyLLMSpeech::Configuration")
      expect(inspect_str).to include("aws_access_key_id")
      expect(inspect_str).not_to include("secret")
    end
  end
end