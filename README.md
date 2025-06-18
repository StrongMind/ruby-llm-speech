# Ruby LLM Speech

A Ruby gem that extends [RubyLLM](https://github.com/crmne/ruby_llm) to add speech functionality using Amazon's Nova Sonic model through AWS Bedrock's bidirectional streaming API.

[![Gem Version](https://badge.fury.io/rb/ruby-llm-speech.svg)](https://badge.fury.io/rb/ruby-llm-speech)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)

## 🎤 Features

- **Seamless RubyLLM Integration**: Extends existing `RubyLLM::Chat` objects with speech methods
- **Bidirectional Audio**: Real-time audio input and output through Nova Sonic
- **Text Transcripts**: Simultaneous text transcription of voice conversations  
- **Tool Calling**: Full support for RubyLLM tools during voice conversations
- **Conversation Resumption**: Resume interrupted conversations with message history
- **Barge-in Support**: Interrupt the AI while it's speaking for natural conversation flow
- **Audio Format Handling**: Built-in support for audio encoding/decoding and format validation
- **Flexible Audio Backend**: Interface-based design allows custom audio implementations

## 📋 Requirements

- Ruby 3.0+
- [RubyLLM gem](https://github.com/crmne/ruby_llm) (~> 1.3)
- AWS credentials with access to Amazon Bedrock Nova Sonic
- Audio implementation (see [Audio Handler](#-audio-handler) section)

## 🚀 Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby-llm-speech'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install ruby-llm-speech
```

## ⚙️ Configuration

Configure the gem with your AWS credentials:

```ruby
require 'ruby_llm_speech'

RubyLLMSpeech.configure do |config|
  config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.aws_region = ENV['AWS_REGION']
  config.voice_id = 'default' # or specific Nova Sonic voice
end
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `aws_access_key_id` | AWS access key ID | `nil` (required) |
| `aws_secret_access_key` | AWS secret access key | `nil` (required) |
| `aws_session_token` | AWS session token (for temporary credentials) | `nil` |
| `aws_region` | AWS region | `"us-east-1"` |
| `voice_id` | Nova Sonic voice ID | `"default"` |
| `model_id` | Nova Sonic model ID | `"amazon.nova-sonic-v1:0"` |
| `request_timeout` | Request timeout in seconds | `300` |
| `audio_sample_rate` | Audio sample rate in Hz | `16000` |
| `audio_format` | Audio format | `"pcm"` |
| `audio_channels` | Number of audio channels | `1` |

## 🎯 Basic Usage

The gem automatically extends `RubyLLM::Chat` with speech methods when both gems are loaded:

```ruby
require 'ruby_llm_speech'

# Create a chat instance with Nova Sonic
chat = RubyLLM.chat
  .with_model("amazon.nova-sonic-v1:0")
  .with_instructions("You are a friendly voice assistant.")

# Set up audio handling (see Audio Handler section)
handler = AudioHandler.new 

# Connect audio input to chat
handler.on_audio_received do |audio_data|
  chat.send_audio(audio_data)
end

# Connect audio output to speakers
chat.on_audio_received do |audio|
  handler.play_audio(audio)
end

# Start voice conversation with text transcript
chat.speak do |chunk|
  print chunk.content # Shows real-time transcript
end
```

## 🔧 Audio Handler

The gem provides an `AudioHandler` interface that must be implemented for your specific platform. The interface handles:

- Recording audio from microphone
- Playing audio to speakers  
- Audio format conversion
- Base64 encoding/decoding

### Basic Interface

```ruby
handler = RubyLLMSpeech::AudioHandler.new

# Set up callbacks
handler.on_audio_received do |base64_audio|
  # Handle recorded audio
end

handler.play_audio do |audio_bytes|
  # Play audio to speakers
end

# Platform-specific implementations must override:
# - start_recording
# - stop_recording
# - play(audio_data)
```

### Example Implementation

See [`examples/audio_handler_example.rb`](examples/audio_handler_example.rb) for a complete implementation using FFI::PortAudio.

## 🎙️ Voice Conversations

### Simple Voice Chat

```ruby
# Start a voice conversation
session_id = chat.speak do |chunk|
  print chunk.content # Real-time transcript
end

# The session continues until stopped
chat.stop_speech
```

### With Tools

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :location, desc: "City name"

  def execute(location:)
    # Implementation
    { temperature: "72°F", condition: "sunny" }
  end
end

chat = RubyLLM.chat
  .with_model("amazon.nova-sonic-v1:0")
  .with_tool(Weather)
  .with_instructions("You can help with weather information.")

chat.speak do |chunk|
  print chunk.content
end

# User can ask: "What's the weather in San Francisco?"
# Tool will be called automatically during voice conversation
```

### Conversation Resumption

```ruby
# Save message history before ending
history = chat.speech_message_history

# Later, resume the conversation
chat.resume_speech(history) do |chunk|
  print chunk.content
end
```

### Interruption Handling

```ruby
# Check if user can interrupt
if chat.can_interrupt?
  chat.interrupt_speech
end

# Monitor conversation state
puts chat.speech_state # :idle, :listening, :speaking, :processing
```

## 🔄 Advanced Features

### Custom Voice Configuration

```ruby
chat.configure_speech(
  voice_id: "custom_voice",
  inference_config: {
    temperature: 0.8,
    topP: 0.9,
    maxTokens: 1024
  }
)
```

### Event Handling

```ruby
# Set up detailed event handling
chat.speech_event_handler.on(:content_start) do |data|
  puts "AI started responding"
end

chat.speech_event_handler.on(:content_end) do |data|
  puts "AI finished responding"
end

chat.speech_event_handler.on(:barge_in) do |data|
  puts "User interrupted"
end
```

### Audio Processing

```ruby
handler = RubyLLMSpeech::AudioHandler.new

# Get recommended audio settings
config = RubyLLMSpeech::AudioHandler.recommended_config
# => { sample_rate: 16000, channels: 1, format: "pcm", bit_depth: 16 }

# Validate audio data
handler.validate_audio_data(audio_bytes, format_info)

# Process audio in chunks
handler.process_audio_stream(large_audio_file, chunk_size: 1024) do |chunk|
  # Process each chunk
end
```

## 🧪 Testing

The gem includes comprehensive RSpec tests with mocked AWS responses:

```bash
# Run all tests
bundle exec rspec

# Run specific test files
bundle exec rspec spec/ruby_llm_speech/configuration_spec.rb
bundle exec rspec spec/ruby_llm_speech/audio_handler_spec.rb

# Run manual integration test (requires AWS credentials)
ruby examples/manual_test_script.rb
```

### Test Coverage

- Configuration management and validation
- Audio encoding/decoding and format validation
- Event handling and conversation state management
- Error handling and edge cases
- Integration with RubyLLM patterns

## 📁 Examples

The `examples/` directory contains complete working examples:

- **`basic_speech_example.rb`**: Simple voice conversation setup
- **`audio_handler_example.rb`**: Complete AudioHandler implementation using FFI::PortAudio
- **`manual_test_script.rb`**: Manual testing script for validation

## 🔧 Development

After checking out the repo, run:

```bash
bin/setup  # Install dependencies
bundle exec rake spec  # Run tests
bundle exec rake rubocop  # Check style
bundle exec rake yard  # Generate documentation
```

### Architecture

The gem consists of several key components:

- **`Configuration`**: Manages AWS credentials and gem settings
- **`NovaSonicClient`**: Wraps AWS Bedrock bidirectional streaming
- **`EventHandler`**: Manages Nova Sonic events and conversation state
- **`AudioHandler`**: Interface for platform-specific audio implementations
- **`ChatExtensions`**: Extends RubyLLM::Chat with speech methods

## 🤝 Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby-llm-speech/ruby-llm-speech.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests for your changes
4. Make sure all tests pass (`bundle exec rake spec`)
5. Ensure code follows style guidelines (`bundle exec rake rubocop`)
6. Commit your changes (`git commit -am 'Add some feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create a new Pull Request

## 📄 License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## 🙏 Acknowledgments

- [RubyLLM](https://github.com/crmne/ruby_llm) for the excellent foundation
- Amazon Web Services for Nova Sonic model and Bedrock platform
- The Ruby community for inspiration and best practices

## 📚 See Also

- [RubyLLM Documentation](https://github.com/crmne/ruby_llm)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Amazon Nova Sonic Model Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-nova.html)
