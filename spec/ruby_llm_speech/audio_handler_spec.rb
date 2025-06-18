# frozen_string_literal: true

RSpec.describe RubyLLMSpeech::AudioHandler do
  let(:handler) { described_class.new }

  describe "#initialize" do
    it "initializes with default state" do
      expect(handler.recording?).to be false
      expect(handler.playing?).to be false
      expect(handler.on_audio_received_callback).to be_nil
      expect(handler.play_audio_callback).to be_nil
    end
  end

  describe "#on_audio_received" do
    it "sets the audio received callback" do
      callback = proc { |data| puts data }
      
      handler.on_audio_received(&callback)
      
      expect(handler.on_audio_received_callback).to eq(callback)
    end
  end

  describe "#play_audio" do
    it "sets the play audio callback" do
      callback = proc { |data| puts data }
      
      handler.play_audio(&callback)
      
      expect(handler.play_audio_callback).to eq(callback)
    end
  end

  describe "#encode_audio" do
    it "encodes audio bytes to base64" do
      audio_bytes = "test audio data"
      
      encoded = handler.encode_audio(audio_bytes)
      
      expect(encoded).to eq(Base64.strict_encode64(audio_bytes))
    end

    it "validates content type before encoding" do
      expect {
        handler.encode_audio("test", content_type: "invalid/format")
      }.to raise_error(RubyLLMSpeech::Error, /Unsupported audio format/)
    end

    it "accepts valid content types" do
      valid_types = %w[audio/pcm audio/wav audio/mp3 audio/m4a audio/flac audio/ogg]
      
      valid_types.each do |content_type|
        expect {
          handler.encode_audio("test", content_type: content_type)
        }.not_to raise_error
      end
    end
  end

  describe "#decode_audio" do
    it "decodes base64 audio data" do
      audio_bytes = "test audio data"
      encoded = Base64.strict_encode64(audio_bytes)
      
      decoded = handler.decode_audio(encoded)
      
      expect(decoded).to eq(audio_bytes)
    end

    it "raises error for invalid base64 data" do
      expect {
        handler.decode_audio("invalid base64!")
      }.to raise_error(RubyLLMSpeech::Error, /Invalid base64 audio data/)
    end
  end

  describe "#validate_audio_format" do
    it "accepts supported formats" do
      supported_formats = %w[audio/pcm audio/wav audio/mp3 audio/m4a audio/flac audio/ogg]
      
      supported_formats.each do |format|
        expect { handler.validate_audio_format(format) }.not_to raise_error
      end
    end

    it "raises error for unsupported formats" do
      expect {
        handler.validate_audio_format("video/mp4")
      }.to raise_error(RubyLLMSpeech::Error, /Unsupported audio format/)
    end

    it "is case insensitive" do
      expect { handler.validate_audio_format("AUDIO/PCM") }.not_to raise_error
      expect { handler.validate_audio_format("Audio/Wav") }.not_to raise_error
    end
  end

  describe ".recommended_config" do
    it "returns recommended audio configuration" do
      config = described_class.recommended_config
      
      expect(config).to eq({
        sample_rate: 16_000,
        channels: 1,
        format: "pcm",
        bit_depth: 16,
        content_type: "audio/pcm"
      })
    end
  end

  describe "#validate_audio_data" do
    it "raises error for empty audio data" do
      expect {
        handler.validate_audio_data("", {})
      }.to raise_error(RubyLLMSpeech::Error, "Audio data cannot be empty")

      expect {
        handler.validate_audio_data(nil, {})
      }.to raise_error(RubyLLMSpeech::Error, "Audio data cannot be empty")
    end

    it "warns about non-recommended sample rates" do
      expect {
        handler.validate_audio_data("audio", { sample_rate: 44_100 })
      }.to output(/Audio sample rate 44100 differs from recommended/).to_stderr
    end

    it "warns about non-recommended channel count" do
      expect {
        handler.validate_audio_data("audio", { channels: 2 })
      }.to output(/Audio has 2 channels, recommended is 1/).to_stderr
    end

    it "does not warn for recommended format" do
      expect {
        handler.validate_audio_data("audio", { sample_rate: 16_000, channels: 1 })
      }.not_to output.to_stderr
    end
  end

  describe "#process_audio_stream" do
    it "yields audio chunks of specified size" do
      audio_data = "a" * 100
      chunks = []
      
      handler.process_audio_stream(audio_data, chunk_size: 10) do |chunk|
        chunks << chunk
      end
      
      expect(chunks.length).to eq(10)
      expect(chunks.first.length).to eq(10)
      expect(chunks.last.length).to eq(10)
    end

    it "handles partial final chunk" do
      audio_data = "a" * 25
      chunks = []
      
      handler.process_audio_stream(audio_data, chunk_size: 10) do |chunk|
        chunks << chunk
      end
      
      expect(chunks.length).to eq(3)
      expect(chunks[0].length).to eq(10)
      expect(chunks[1].length).to eq(10)
      expect(chunks[2].length).to eq(5)
    end

    it "returns enumerator when no block given" do
      audio_data = "a" * 20
      
      enumerator = handler.process_audio_stream(audio_data, chunk_size: 5)
      
      expect(enumerator).to be_a(Enumerator)
      expect(enumerator.to_a.length).to eq(4)
    end
  end

  describe "#start_recording" do
    it "raises NotImplementedError" do
      expect { handler.start_recording }.to raise_error(NotImplementedError)
    end

    it "sets recording state before raising error" do
      begin
        handler.start_recording
      rescue NotImplementedError
        # Expected
      end
      
      expect(handler.recording?).to be true
    end
  end

  describe "#stop_recording" do
    it "raises NotImplementedError" do
      expect { handler.stop_recording }.to raise_error(NotImplementedError)
    end
  end

  describe "#play" do
    it "calls play_audio_callback when set" do
      audio_data = "test audio"
      callback_called = false
      
      handler.play_audio { |data| callback_called = true }
      handler.play(audio_data)
      
      expect(callback_called).to be true
    end

    it "raises NotImplementedError when no callback set" do
      expect {
        handler.play("test audio")
      }.to raise_error(NotImplementedError, /No play_audio callback set/)
    end

    it "sets playing state during playback" do
      handler.play_audio { |data| expect(handler.playing?).to be true }
      handler.play("test audio")
    end

    it "resets playing state after playback" do
      handler.play_audio { |data| }
      handler.play("test audio")
      
      expect(handler.playing?).to be false
    end
  end

  describe "#convert_audio_format" do
    it "returns audio data unchanged when formats match" do
      audio_data = "test audio"
      format = { sample_rate: 16_000, channels: 1, format: "pcm", bit_depth: 16 }
      
      result = handler.convert_audio_format(audio_data, from_format: format, to_format: format)
      
      expect(result).to eq(audio_data)
    end

    it "raises NotImplementedError for different formats" do
      audio_data = "test audio"
      from_format = { sample_rate: 44_100, channels: 2 }
      to_format = { sample_rate: 16_000, channels: 1 }
      
      expect {
        handler.convert_audio_format(audio_data, from_format: from_format, to_format: to_format)
      }.to raise_error(NotImplementedError, /Audio format conversion not implemented/)
    end
  end
end