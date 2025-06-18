# Ruby LLM Speech Examples

This directory contains comprehensive examples demonstrating how to use the ruby-llm-speech gem in various scenarios.

## 🚀 Quick Start

Before running any examples, make sure to set your AWS credentials:

```bash
export AWS_ACCESS_KEY_ID="your_aws_access_key"
export AWS_SECRET_ACCESS_KEY="your_aws_secret_key"
export AWS_REGION="us-east-1"
```

Then run any example:

```bash
ruby examples/simple_voice_chat.rb
```

## 📁 Available Examples

### 1. Simple Voice Chat (`simple_voice_chat.rb`)

**What it demonstrates:**
- Basic voice interaction with Nova Sonic
- Text-to-speech functionality
- Conversation transcripts
- Session management and recovery

**Key features:**
- Simple setup and configuration
- Demonstration of core speech functionality
- Transcript viewing and summary
- Error handling examples

**Run it:**
```bash
ruby examples/simple_voice_chat.rb
```

### 2. Weather Assistant (`weather_assistant.rb`)

**What it demonstrates:**
- Voice interaction with tool calling
- Multiple tool integration (Weather, Calculator, Time)
- Complex multi-tool queries
- Voice configuration changes
- Advanced transcript management

**Key features:**
- Enhanced weather tool with realistic data
- Multi-tool voice commands
- Voice switching demonstration
- Conversation export functionality
- Production-like error handling

**Run it:**
```bash
ruby examples/weather_assistant.rb
```

### 3. Custom Audio Handler (`custom_handler.rb`)

**What it demonstrates:**
- How to create custom audio handlers
- Different handler patterns and use cases
- Audio event logging and analytics
- Buffer management for audio data

**Key features:**
- **LoggingAudioHandler**: Detailed event logging with file output
- **AudioBufferHandler**: Circular buffer for recent audio/transcript events
- **AnalyticsAudioHandler**: Session analytics and performance metrics
- Handler composition patterns

**Run it:**
```bash
ruby examples/custom_handler.rb
```

## 🛠️ Example Use Cases

### Basic Voice Interaction
```ruby
# From simple_voice_chat.rb
chat = SimpleVoiceChat.new
chat.speak("Hello! How can I help you today?")
transcript = chat.get_transcript
```

### Voice + Tools
```ruby
# From weather_assistant.rb
assistant = WeatherAssistant.new
assistant.speak("What's the weather in San Francisco and what time is it?")
# Automatically calls weather and time tools
```

### Custom Audio Processing
```ruby
# From custom_handler.rb
handler = AnalyticsAudioHandler.new
chat.configure_speech(audio_handler: handler)
chat.speak("Track this conversation")
analytics = handler.get_analytics
```

## 🔧 Configuration Examples

### Basic Configuration
```ruby
RubyLLMSpeech.configure do |config|
  config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.aws_region = 'us-east-1'
  config.default_voice = 'Joanna'
end
```

### Advanced Configuration
```ruby
chat.configure_speech(
  voice: 'Amy',
  temperature: 0.7,
  system_prompt: 'You are a helpful assistant.',
  tools: [WeatherTool.new, CalculatorTool.new],
  transcript_enabled: true,
  audio_handler: CustomAudioHandler.new
)
```

## 📊 What Each Example Teaches

| Example | Voice Interaction | Tool Calling | Custom Handlers | Advanced Features |
|---------|------------------|--------------|-----------------|-------------------|
| `simple_voice_chat.rb` | ✅ Basic | ❌ | ❌ | Session recovery |
| `weather_assistant.rb` | ✅ Advanced | ✅ Multi-tool | ❌ | Voice switching, Export |
| `custom_handler.rb` | ✅ Basic | ❌ | ✅ 3 examples | Analytics, Buffering |

## 🎯 Learning Path

1. **Start with `simple_voice_chat.rb`** - Learn basic voice interaction
2. **Try `weather_assistant.rb`** - Understand tool integration
3. **Explore `custom_handler.rb`** - Master audio event handling

## 🔍 Code Patterns

### Error Handling Pattern
```ruby
begin
  chat.speak("Hello world")
rescue RubyLLMSpeech::ConfigurationError => e
  puts "Configuration issue: #{e.message}"
rescue RubyLLMSpeech::Error => e
  puts "General error: #{e.message}"
end
```

### Tool Integration Pattern
```ruby
class MyTool
  def self.description
    "Tool description"
  end
  
  def self.parameters
    { param: { type: "string", required: true } }
  end
  
  def execute(param:)
    # Tool logic here
  end
end

chat.with_tool(MyTool.new)
```

### Custom Handler Pattern
```ruby
class MyHandler < RubyLLMSpeech::AudioHandler
  def initialize
    super
    on_audio_received { |audio, meta| handle_audio(audio, meta) }
    on_transcript_received { |text, meta| handle_transcript(text, meta) }
  end
  
  private
  
  def handle_audio(audio_data, metadata)
    # Your audio processing logic
  end
  
  def handle_transcript(transcript, metadata)
    # Your transcript processing logic
  end
end
```

## 🚨 Troubleshooting

### Common Issues

1. **AWS Credentials Not Set**
   ```
   ❌ Configuration Error: AWS credentials required
   ```
   **Solution**: Set environment variables or configure explicitly

2. **Network Connection Issues**
   ```
   ❌ Connection Error: Failed to connect to AWS Bedrock
   ```
   **Solution**: Check internet connection and AWS region

3. **Tool Execution Errors**
   ```
   ❌ Tool execution failed: Invalid parameters
   ```
   **Solution**: Check tool parameter definitions and input data

### Debug Mode

Enable debug logging to see detailed information:

```ruby
RubyLLMSpeech.configure do |config|
  config.log_level = Logger::DEBUG
end
```

## 📝 Next Steps

After running these examples:

1. **Integrate with your app**: Add speech capabilities to your existing RubyLLM application
2. **Create custom tools**: Build tools specific to your domain
3. **Implement audio handlers**: Create handlers for your audio system
4. **Production deployment**: Add proper error handling and monitoring

## 🤝 Contributing

Found an issue with an example or have an idea for a new one? Please open an issue or submit a pull request!

## 📚 Additional Resources

- [Main README](../README.md) - Complete gem documentation
- [API Documentation](../lib/ruby_llm_speech/) - Detailed API reference
- [RubyLLM Documentation](https://github.com/crmne/ruby_llm) - Base gem documentation