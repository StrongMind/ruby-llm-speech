# RubyLLM Speech

A beautiful Ruby gem that extends [RubyLLM](https://github.com/crmne/ruby_llm) to add voice interaction capabilities using Amazon Nova Sonic. Enables users to interface with Nova Sonic using their spoken voice and hear the responses, while maintaining a running transcript of the conversation.

## Features

- 🎤 **Voice Interaction**: Speak directly to Nova Sonic and receive audio responses
- 📝 **Conversation Transcripts**: Automatic transcription and conversation history
- 🛠️ **Tool Integration**: Voice-activated tool calling (just like regular LLMs)
- 🔄 **Session Recovery**: Resume voice conversations where you left off
- ⚙️ **Beautiful API**: Intuitive, chainable methods consistent with RubyLLM patterns
- 🎛️ **Configurable**: Voice selection, temperature control, system prompts, and more
- 🔒 **Error Handling**: Comprehensive error recovery with exponential backoff
- 📊 **Logging**: Built-in logging for debugging and monitoring

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby-llm-speech'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ruby-llm-speech

## Quick Start

```ruby
require 'ruby_llm_speech'

# Configure AWS credentials
RubyLLMSpeech.configure do |config|
  config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.aws_region = 'us-east-1'
  config.default_voice = 'Matthew'
end

# Create a speech-enabled chat instance
chat = RubyLLMSpeech::ChatExtension::ClassMethods.speak_with_nova_sonic(
  voice: 'Joanna',
  temperature: 0.7,
  system_prompt: 'You are a helpful voice assistant.'
)

# Send text to be spoken
chat.speak("Hello! How can I help you today?")

# Send audio data for processing
audio_data = File.read('audio_input.pcm')
chat.speak(audio_data: audio_data)

# Get conversation transcript
puts chat.get_transcript
```

## Basic Usage

### Creating a Speech-Enabled Chat

```ruby
# Method 1: Using the class method
chat = YourChatClass.speak_with_nova_sonic(
  voice: 'Amy',
  temperature: 0.8,
  system_prompt: 'You are a friendly assistant.'
)

# Method 2: Configure manually
chat = YourChatClass.new
chat.configure_speech(
  aws_access_key_id: 'your_key',
  aws_secret_access_key: 'your_secret',
  aws_region: 'us-east-1',
  voice: 'Matthew',
  temperature: 0.7,
  transcript_enabled: true
)
```

### Voice Interaction

```ruby
# Text to speech
chat.speak("Tell me about the weather")

# Audio to text processing
audio_data = record_audio() # Your audio recording method
chat.speak(audio_data: audio_data)

# With custom audio handler
chat.configure_speech(
  audio_handler: MyCustomAudioHandler.new
)

# Start/stop voice sessions
chat.start_voice_session do |audio_data, metadata|
  # Handle incoming audio
  play_audio(audio_data)
end

chat.close_voice_session
```

### Configuration Options

```ruby
chat.configure_speech(
  # AWS Configuration
  aws_access_key_id: 'your_key_id',
  aws_secret_access_key: 'your_secret',
  aws_region: 'us-east-1',
  
  # Voice Configuration
  voice: 'Joanna',           # Matthew, Joanna, Amy, etc.
  temperature: 0.7,          # Creativity level (0.0 - 1.0)
  
  # Session Management
  session_id: 'my_session_123',  # Custom session ID
  transcript_enabled: true,      # Enable conversation logging
  
  # Audio Handling
  audio_handler: MyAudioHandler.new,
  
  # System Behavior
  system_prompt: 'You are a helpful assistant.'
)
```

## Tool Integration

RubyLLM Speech seamlessly supports tool calling, just like regular LLMs:

```ruby
# Define a tool
class WeatherTool
  def self.description
    "Gets current weather information for a specified location"
  end

  def self.parameters
    {
      location: {
        type: "string",
        description: "The city and state/country for weather lookup",
        required: true
      }
    }
  end

  def execute(location:)
    # Your weather API call here
    {
      location: location,
      temperature: "72°F",
      conditions: "sunny"
    }
  end
end

# Add tools to your speech chat
chat.configure_speech(
  tools: [WeatherTool.new]
)

# Or add tools after configuration
chat.with_tool(WeatherTool.new)
chat.with_tools(CalculatorTool.new, TimeTool.new)

# Voice commands will now trigger tools
chat.speak("What's the weather like in San Francisco?")
# The tool will be called automatically and results spoken back
```

### Example Tools

The gem includes several example tools:

```ruby
# Weather tool
weather_tool = RubyLLMSpeech::ExampleTools::WeatherTool.new
result = weather_tool.execute(location: "New York")

# Calculator tool  
calc_tool = RubyLLMSpeech::ExampleTools::CalculatorTool.new
result = calc_tool.execute(expression: "15 * 7")

# Time tool
time_tool = RubyLLMSpeech::ExampleTools::TimeTool.new
result = time_tool.execute(timezone: "UTC")
```

## Conversation Transcripts

### Basic Transcript Usage

```ruby
# Get transcript in different formats
text_transcript = chat.get_transcript(format: :text)
hash_transcript = chat.get_transcript(format: :hash)
summary = chat.get_transcript(format: :summary)

# Export transcript to file
chat.export_transcript("conversation.txt", format: :text)
chat.export_transcript("conversation.json", format: :json)

# Clear transcript
chat.clear_transcript!

# Add custom messages to transcript
chat.add_transcript_message(
  role: :user, 
  content: "Custom message",
  type: :note
)
```

### Transcript Filtering

```ruby
# Get messages by role
user_messages = chat.conversation_transcript.get_messages(role: :user)
assistant_messages = chat.conversation_transcript.get_messages(role: :assistant)
tool_messages = chat.conversation_transcript.get_messages(type: :tool_execution)

# Get recent messages
recent = chat.conversation_transcript.get_messages(since: 1.hour.ago)

# Get conversation summary
summary = chat.conversation_transcript.get_conversation_summary
puts "Total messages: #{summary[:total_messages]}"
puts "User messages: #{summary[:user_messages]}"
puts "Tool calls: #{summary[:tool_calls]}"
```

## Session Recovery

```ruby
# Save session ID for later recovery
session_id = chat.session_id

# Later, recover the session
chat.recover_session(session_id)

# Sessions are automatically saved/restored when transcript is enabled
chat.configure_speech(transcript_enabled: true)
# Transcripts are saved to ~/.ruby_llm_speech/transcripts/
```

## Audio Handling

### Custom Audio Handler

```ruby
class MyAudioHandler < RubyLLMSpeech::AudioHandler
  def initialize
    super
    
    # Set up audio callbacks
    on_audio_received do |audio_data, metadata|
      # Handle incoming audio from Nova Sonic
      play_audio(audio_data)
      puts "Received audio: #{metadata[:length]} bytes"
    end
    
    on_transcript_received do |transcript, metadata|
      # Handle transcript updates
      puts "Transcript: #{transcript}"
      puts "Confidence: #{metadata[:confidence]}"
    end
  end
  
  private
  
  def play_audio(audio_data)
    # Your audio playback implementation
    # This is where you'd integrate with your audio system
    puts "Playing #{audio_data.length} bytes of audio"
  end
end

# Use your custom handler
chat.configure_speech(audio_handler: MyAudioHandler.new)
```

### Default Audio Handler

The gem includes a default audio handler that logs audio events:

```ruby
# Uses the default handler (logs to console)
chat.configure_speech  # Default handler is used

# Access the handler
handler = chat.audio_handler
handler.on_audio_received do |audio_data, metadata|
  puts "Got audio: #{audio_data.length} bytes"
end
```

## Configuration

### Global Configuration

```ruby
RubyLLMSpeech.configure do |config|
  config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.aws_region = 'us-east-1'
  config.default_voice = 'Matthew'
  config.log_level = Logger::DEBUG
  config.error_retry_attempts = 3
  config.connection_timeout = 30
end
```

### Runtime Configuration Updates

```ruby
# Update voice during conversation
chat.update_voice('Amy')

# Update temperature
chat.update_temperature(0.9)

# Update system prompt
chat.set_system_prompt('You are now a creative writing assistant.')
```

## Error Handling

The gem includes comprehensive error handling with automatic retry logic:

```ruby
begin
  chat.speak("Hello world")
rescue RubyLLMSpeech::ConnectionError => e
  puts "Connection issue: #{e.message}"
rescue RubyLLMSpeech::ModelError => e  
  puts "Model error: #{e.message}"
rescue RubyLLMSpeech::SessionError => e
  puts "Session error: #{e.message}"
rescue RubyLLMSpeech::Error => e
  puts "General error: #{e.message}"
end

# Automatic retry with exponential backoff
chat.retry_with_backoff(max_attempts: 5) do
  chat.speak("This will retry on connection/model errors")
end
```

## Logging

```ruby
# Set log level
RubyLLMSpeech.logger.level = Logger::DEBUG

# Custom logger
RubyLLMSpeech.logger = Logger.new('speech.log')

# Logs include:
# - Session management events
# - Audio processing events  
# - Tool execution
# - Error handling
# - Transcript operations
```

## Advanced Usage

### Chaining Methods

```ruby
chat = MyChat.speak_with_nova_sonic(voice: 'Joanna')
  .with_tool(WeatherTool.new)
  .with_tool(CalculatorTool.new)
  .set_system_prompt('You are a helpful assistant.')

chat.speak("What's 15 times 7, and what's the weather in Miami?")
```

### Custom Session Management

```ruby
# Custom session ID
chat.configure_speech(session_id: "user_#{user.id}_#{Date.today}")

# Recover specific session
chat.recover_session("user_123_2024-06-18")

# Check session status
puts "Session active: #{chat.speech_configured?}"
puts "Session ID: #{chat.session_id}"
```

### Transcript Processing

```ruby
# Process transcript data
transcript = chat.conversation_transcript
transcript.messages.each do |message|
  puts "[#{message.timestamp}] #{message.role}: #{message.content}"
  
  if message.type == :tool_execution
    puts "  Tool: #{message.metadata[:tool_name]}"
    puts "  Result: #{message.metadata[:result]}"
  end
end

# Export with custom formatting
text = transcript.to_text(
  include_timestamps: true,
  include_metadata: true
)
```

## Integration with Existing RubyLLM Code

RubyLLM Speech is designed to seamlessly extend existing RubyLLM applications:

```ruby
# Your existing RubyLLM chat
class MyChatBot
  include RubyLLM::Chat
  
  def initialize
    # Your existing setup
  end
end

# Add speech capabilities
class MyChatBot
  include RubyLLMSpeech::ChatExtension  # Add this line
  
  # All your existing methods work unchanged
  # New speech methods are now available
end

# Now you can use both text and voice
bot = MyChatBot.new
bot.chat("Hello")  # Original text method
bot.configure_speech(voice: 'Amy')
bot.speak("Hello")  # New voice method
```

## Examples

See the `examples/` directory for complete sample applications:

- `examples/simple_voice_chat.rb` - Basic voice interaction
- `examples/weather_assistant.rb` - Voice assistant with weather tool
- `examples/audio_recorder.rb` - Audio recording integration
- `examples/custom_handler.rb` - Custom audio handler implementation

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby-llm/ruby-llm-speech.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

### Version 0.1.0
- Initial release
- Basic voice interaction with Nova Sonic
- Tool calling support
- Conversation transcripts
- Session recovery
- Comprehensive error handling
- Example tools and audio handlers
