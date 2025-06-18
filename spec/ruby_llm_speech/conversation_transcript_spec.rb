# frozen_string_literal: true

RSpec.describe RubyLLMSpeech::ConversationTranscript do
  let(:session_id) { "test_session_123" }
  let(:transcript) { described_class.new(session_id: session_id) }

  describe "#initialize" do
    it "creates a new transcript with session ID" do
      expect(transcript.session_id).to eq(session_id)
      expect(transcript.messages).to eq([])
      expect(transcript.started_at).to be_a(Time)
    end

    it "accepts metadata" do
      metadata = { user_id: "123", language: "en" }
      transcript_with_metadata = described_class.new(session_id: session_id, metadata: metadata)

      expect(transcript_with_metadata.metadata).to eq(metadata)
    end
  end

  describe "#add_message" do
    it "adds a message to the transcript" do
      message = transcript.add_message(role: :user, content: "Hello")

      expect(transcript.messages.length).to eq(1)
      expect(message.role).to eq(:user)
      expect(message.content).to eq("Hello")
      expect(message.type).to eq(:text)
    end

    it "accepts custom type and metadata" do
      message = transcript.add_message(
        role: :assistant,
        content: "Hi there",
        type: :speech,
        metadata: { voice: "Matthew" }
      )

      expect(message.type).to eq(:speech)
      expect(message.metadata[:voice]).to eq("Matthew")
    end
  end

  describe "#add_user_speech" do
    it "adds a user speech message" do
      message = transcript.add_user_speech("Hello world", { confidence: 0.95 })

      expect(message.role).to eq(:user)
      expect(message.content).to eq("Hello world")
      expect(message.type).to eq(:speech)
      expect(message.metadata[:input_type]).to eq("audio")
      expect(message.metadata[:confidence]).to eq(0.95)
    end
  end

  describe "#add_assistant_speech" do
    it "adds an assistant speech message" do
      message = transcript.add_assistant_speech("How can I help?", { voice: "Joanna" })

      expect(message.role).to eq(:assistant)
      expect(message.content).to eq("How can I help?")
      expect(message.type).to eq(:speech)
      expect(message.metadata[:output_type]).to eq("audio")
      expect(message.metadata[:voice]).to eq("Joanna")
    end
  end

  describe "#add_system_message" do
    it "adds a system message" do
      message = transcript.add_system_message("You are a helpful assistant")

      expect(message.role).to eq(:system)
      expect(message.content).to eq("You are a helpful assistant")
      expect(message.type).to eq(:system)
    end
  end

  describe "#add_tool_call" do
    it "adds a tool call message" do
      arguments = { location: "New York" }
      result = { temperature: "72°F", conditions: "sunny" }
      
      message = transcript.add_tool_call("WeatherTool", "execute", arguments, result)

      expect(message.role).to eq(:tool)
      expect(message.content).to include("WeatherTool.execute")
      expect(message.type).to eq(:tool_execution)
      expect(message.metadata[:tool_name]).to eq("WeatherTool")
      expect(message.metadata[:result]).to eq(result)
    end
  end

  describe "#add_error" do
    it "adds an error message" do
      message = transcript.add_error("Connection failed")

      expect(message.role).to eq(:system)
      expect(message.content).to eq("Error: Connection failed")
      expect(message.type).to eq(:error)
      expect(message.metadata[:error]).to be true
    end
  end

  describe "#get_messages" do
    before do
      transcript.add_user_speech("Hello")
      transcript.add_assistant_speech("Hi there")
      transcript.add_tool_call("WeatherTool", "execute", {}, {})
      transcript.add_error("Test error")
    end

    it "returns all messages by default" do
      messages = transcript.get_messages

      expect(messages.length).to eq(4)
    end

    it "filters by role" do
      user_messages = transcript.get_messages(role: :user)
      assistant_messages = transcript.get_messages(role: :assistant)

      expect(user_messages.length).to eq(1)
      expect(assistant_messages.length).to eq(1)
    end

    it "filters by type" do
      speech_messages = transcript.get_messages(type: :speech)
      tool_messages = transcript.get_messages(type: :tool_execution)

      expect(speech_messages.length).to eq(2)
      expect(tool_messages.length).to eq(1)
    end

    it "filters by timestamp" do
      sleep(0.01) # Ensure time difference
      cutoff_time = Time.now
      sleep(0.01) # Ensure time difference
      transcript.add_user_speech("After cutoff")

      recent_messages = transcript.get_messages(since: cutoff_time)

      expect(recent_messages.length).to eq(1)
      expect(recent_messages.first.content).to eq("After cutoff")
    end
  end

  describe "#get_conversation_summary" do
    before do
      transcript.add_user_speech("Hello")
      transcript.add_assistant_speech("Hi")
      transcript.add_tool_call("WeatherTool", "execute", {}, {})
    end

    it "returns conversation statistics" do
      summary = transcript.get_conversation_summary

      expect(summary[:session_id]).to eq(session_id)
      expect(summary[:total_messages]).to eq(3)
      expect(summary[:user_messages]).to eq(1)
      expect(summary[:assistant_messages]).to eq(1)
      expect(summary[:tool_calls]).to eq(1)
      expect(summary[:last_activity]).to be_a(Time)
    end
  end

  describe "#to_text" do
    before do
      transcript.add_user_speech("Hello")
      transcript.add_assistant_speech("Hi there")
    end

    it "converts transcript to text format" do
      text = transcript.to_text

      expect(text).to include("USER: Hello")
      expect(text).to include("ASSISTANT: Hi there")
    end

    it "includes timestamps when requested" do
      text = transcript.to_text(include_timestamps: true)

      expect(text).to match(/\[\d{2}:\d{2}:\d{2}\]/)
    end

    it "excludes timestamps when requested" do
      text = transcript.to_text(include_timestamps: false)

      expect(text).not_to match(/\[\d{2}:\d{2}:\d{2}\]/)
    end
  end

  describe "#to_hash" do
    before do
      transcript.add_user_speech("Hello")
    end

    it "converts transcript to hash format" do
      hash = transcript.to_hash

      expect(hash[:session_id]).to eq(session_id)
      expect(hash[:started_at]).to be_a(Time)
      expect(hash[:messages]).to be_an(Array)
      expect(hash[:messages].first[:role]).to eq(:user)
    end
  end

  describe "#export_to_file" do
    let(:temp_file) { "/tmp/test_transcript.txt" }

    after do
      File.delete(temp_file) if File.exist?(temp_file)
    end

    before do
      transcript.add_user_speech("Hello")
      transcript.add_assistant_speech("Hi")
    end

    it "exports transcript to text file" do
      transcript.export_to_file(temp_file, format: :text)

      expect(File.exist?(temp_file)).to be true
      content = File.read(temp_file)
      expect(content).to include("USER: Hello")
      expect(content).to include("ASSISTANT: Hi")
    end

    it "exports transcript to JSON file" do
      json_file = "/tmp/test_transcript.json"
      
      begin
        transcript.export_to_file(json_file, format: :json)

        expect(File.exist?(json_file)).to be true
        content = File.read(json_file)
        parsed = JSON.parse(content)
        expect(parsed["session_id"]).to eq(session_id)
      ensure
        File.delete(json_file) if File.exist?(json_file)
      end
    end
  end

  describe "#clear!" do
    before do
      transcript.add_user_speech("Hello")
      transcript.add_assistant_speech("Hi")
    end

    it "clears all messages" do
      expect(transcript.message_count).to eq(2)

      transcript.clear!

      expect(transcript.message_count).to eq(0)
      expect(transcript.empty?).to be true
    end
  end

  describe "#empty?" do
    it "returns true when no messages" do
      expect(transcript.empty?).to be true
    end

    it "returns false when messages exist" do
      transcript.add_user_speech("Hello")

      expect(transcript.empty?).to be false
    end
  end
end

RSpec.describe RubyLLMSpeech::TranscriptMessage do
  let(:message) { described_class.new(role: :user, content: "Hello", type: :speech) }

  describe "#initialize" do
    it "creates a message with required attributes" do
      expect(message.role).to eq(:user)
      expect(message.content).to eq("Hello")
      expect(message.type).to eq(:speech)
      expect(message.timestamp).to be_a(Time)
    end

    it "converts role and type to symbols" do
      string_message = described_class.new(role: "assistant", content: "Hi", type: "text")

      expect(string_message.role).to eq(:assistant)
      expect(string_message.type).to eq(:text)
    end
  end

  describe "#to_hash" do
    it "returns message as hash" do
      hash = message.to_hash

      expect(hash[:role]).to eq(:user)
      expect(hash[:content]).to eq("Hello")
      expect(hash[:type]).to eq(:speech)
      expect(hash[:timestamp]).to be_a(Time)
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      expect(message.to_s).to eq("user: Hello")
    end
  end
end