# frozen_string_literal: true

RSpec.describe RubyLLMSpeech do
  it "has a version number" do
    expect(RubyLLMSpeech::VERSION).not_to be_nil
  end

  describe "error classes" do
    it "defines base Error class" do
      expect(RubyLLMSpeech::Error).to be < StandardError
    end

    it "defines ConnectionError class" do
      expect(RubyLLMSpeech::ConnectionError).to be < RubyLLMSpeech::Error
    end

    it "defines AuthenticationError class" do
      expect(RubyLLMSpeech::AuthenticationError).to be < RubyLLMSpeech::Error
    end

    it "defines ModelError class" do
      expect(RubyLLMSpeech::ModelError).to be < RubyLLMSpeech::Error
    end
  end
end