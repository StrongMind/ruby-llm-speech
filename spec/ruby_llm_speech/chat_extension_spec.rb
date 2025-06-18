# frozen_string_literal: true

RSpec.describe RubyLLMSpeech::ChatExtension do
  let(:mock_chat_class) do
    Class.new do
      include RubyLLMSpeech::ChatExtension
    end
  end

  let(:chat_instance) { mock_chat_class.new }

  before do
    RubyLLMSpeech.configure do |config|
      config.aws_access_key_id = "test_key"
      config.aws_secret_access_key = "test_secret"
      config.aws_region = "us-east-1"
      config.default_voice = "Matthew"
    end
  end

  describe ".speak_with_nova_sonic" do
    it "creates a new chat instance with speech configured" do
      chat = mock_chat_class.speak_with_nova_sonic(voice: "Amy")
      
      expect(chat).to be_a(mock_chat_class)
      expect(chat.speech_configured?).to be true
    end
  end

  describe "#configure_speech" do
    it "configures speech with provided options" do
      result = chat_instance.configure_speech(
        voice: "Joanna",
        temperature: 0.8,
        system_prompt: "You are a helpful assistant"
      )

      expect(result).to eq(chat_instance)
      expect(chat_instance.speech_configured?).to be true
      expect(chat_instance.speech_configuration[:voice]).to eq("Joanna")
      expect(chat_instance.speech_configuration[:temperature]).to eq(0.8)
      expect(chat_instance.speech_configuration[:system_prompt]).to eq("You are a helpful assistant")
    end

    it "uses default configuration values when not provided" do
      chat_instance.configure_speech

      expect(chat_instance.speech_configuration[:aws_access_key_id]).to eq("test_key")
      expect(chat_instance.speech_configuration[:voice]).to eq("Matthew")
    end

    it "generates a session ID when not provided" do
      chat_instance.configure_speech

      expect(chat_instance.session_id).to match(/^ruby_llm_speech_\d+_[a-f0-9]{16}$/)
    end

    it "uses provided session ID" do
      session_id = "custom_session_123"
      chat_instance.configure_speech(session_id: session_id)

      expect(chat_instance.session_id).to eq(session_id)
    end
  end

  describe "#speak" do
    before do
      chat_instance.configure_speech
    end

    it "raises error when neither content nor audio_data provided" do
      expect { chat_instance.speak }.to raise_error(ArgumentError, "Either content or audio_data must be provided")
    end

    it "handles text content" do
      expect(chat_instance.nova_sonic_client).to receive(:text_to_speech).with(
        text: "Hello world",
        voice: "Matthew",
        session_id: chat_instance.session_id
      )

      chat_instance.speak("Hello world")
    end

    it "handles audio data" do
      audio_data = [1, 2, 3, 4]
      expect(chat_instance.nova_sonic_client).to receive(:speech_to_text).with(
        audio_data: audio_data,
        session_id: chat_instance.session_id
      )

      chat_instance.speak(audio_data: audio_data)
    end
  end

  describe "#set_system_prompt" do
    before do
      chat_instance.configure_speech
    end

    it "sets the system prompt" do
      result = chat_instance.set_system_prompt("You are an AI assistant")

      expect(result).to eq(chat_instance)
      expect(chat_instance.get_system_prompt).to eq("You are an AI assistant")
    end

    it "updates nova sonic client with system prompt" do
      expect(chat_instance.nova_sonic_client).to receive(:update_system_prompt).with("Test prompt")

      chat_instance.set_system_prompt("Test prompt")
    end
  end

  describe "#update_voice" do
    before do
      chat_instance.configure_speech
    end

    it "updates the voice configuration" do
      result = chat_instance.update_voice("Amy")

      expect(result).to eq(chat_instance)
      expect(chat_instance.speech_configuration[:voice]).to eq("Amy")
    end

    it "updates nova sonic client with new voice" do
      expect(chat_instance.nova_sonic_client).to receive(:update_voice).with("Amy")

      chat_instance.update_voice("Amy")
    end
  end

  describe "#update_temperature" do
    before do
      chat_instance.configure_speech
    end

    it "updates the temperature configuration" do
      result = chat_instance.update_temperature(0.9)

      expect(result).to eq(chat_instance)
      expect(chat_instance.speech_configuration[:temperature]).to eq(0.9)
    end

    it "updates nova sonic client with new temperature" do
      expect(chat_instance.nova_sonic_client).to receive(:update_temperature).with(0.9)

      chat_instance.update_temperature(0.9)
    end
  end

  describe "#recover_session" do
    before do
      chat_instance.configure_speech
    end

    it "recovers a session with given session ID" do
      old_session_id = chat_instance.session_id
      new_session_id = "recovered_session_123"

      expect(chat_instance.nova_sonic_client).to receive(:recover_session).with(new_session_id)

      result = chat_instance.recover_session(new_session_id)

      expect(result).to eq(chat_instance)
      expect(chat_instance.session_id).to eq(new_session_id)
      expect(chat_instance.session_id).not_to eq(old_session_id)
    end
  end

  describe "#speech_configured?" do
    it "returns false when speech is not configured" do
      expect(chat_instance.speech_configured?).to be false
    end

    it "returns true when speech is configured" do
      chat_instance.configure_speech

      expect(chat_instance.speech_configured?).to be true
    end
  end

  describe "error handling" do
    it "raises error when trying to speak without configuration" do
      expect { chat_instance.speak("Hello") }.to raise_error(RubyLLMSpeech::Error, "Speech not configured. Call configure_speech first.")
    end

    it "raises error when trying to start voice session without configuration" do
      expect { chat_instance.start_voice_session }.to raise_error(RubyLLMSpeech::Error, "Speech not configured. Call configure_speech first.")
    end
  end
end