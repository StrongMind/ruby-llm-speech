# Ruby LLM Speech Gem Development Plan

## Overview
Build a Ruby gem called `ruby-llm-speech` that extends the RubyLLM gem to add speech functionality using Amazon's Nova Sonic model through AWS Bedrock's bidirectional streaming API.

## Project Structure
```
ruby-llm-speech/
├── lib/
│   ├── ruby_llm_speech.rb
│   ├── ruby_llm_speech/
│   │   ├── version.rb
│   │   ├── chat_extensions.rb
│   │   ├── audio_handler.rb
│   │   ├── nova_sonic_client.rb
│   │   ├── audio_stream.rb
│   │   └── event_handler.rb
├── spec/
│   ├── spec_helper.rb
│   ├── ruby_llm_speech_spec.rb
│   ├── chat_extensions_spec.rb
│   ├── audio_handler_spec.rb
│   ├── nova_sonic_client_spec.rb
│   └── audio_stream_spec.rb
├── ruby-llm-speech.gemspec
├── Gemfile
├── Rakefile
├── README.md
├── .rspec
├── .rubocop.yml
└── .gitignore
```

## Implementation Steps

### [ ] Step 1: Create gemspec file and basic gem structure
- Create `ruby-llm-speech.gemspec` with proper dependencies
- Set up Bundler gem structure
- Add dependencies: `ruby_llm`, `aws-sdk-bedrockruntime`
- Configure Ruby version compatibility (3.0+)

### [ ] Step 2: Create core Nova Sonic client wrapper
- Build `NovaSonicClient` class to wrap AWS Bedrock bidirectional streaming
- Implement session management for streaming connections
- Handle AWS authentication and configuration
- Implement event-based communication (sessionStart, audioInput, textInput)
- Handle response events (audioOutput, textOutput, contentStart, contentEnd)

### [ ] Step 3: Create audio handling infrastructure
- Build `AudioHandler` class for audio input/output management
- Support audio recording callbacks (`on_audio_received`)
- Support audio playback callbacks (`play_audio`)
- Handle audio format conversions (base64 encoding/decoding)
- Abstract audio I/O to allow custom implementations

### [ ] Step 4: Extend RubyLLM::Chat with speech methods
- Create `ChatExtensions` module to extend RubyLLM::Chat
- Add `#speak` method for starting speech conversations
- Add `#send_audio` method for sending audio data
- Add `#on_audio_received` callback for handling model audio responses
- Implement streaming transcript display through blocks
- Ensure compatibility with existing RubyLLM patterns

### [ ] Step 5: Implement bidirectional streaming and event handling
- Create `EventHandler` class for managing Nova Sonic events
- Handle barge-in functionality (user interruptions)
- Implement turn-taking and conversation state management
- Support system prompts and conversation context
- Handle tool calling events and responses

### [ ] Step 6: Add voice and model configuration
- Support voice selection for Nova Sonic
- Allow system prompt configuration
- Integrate with RubyLLM's tool system for function calling
- Support inference configuration (temperature, maxTokens, etc.)

### [ ] Step 7: Write comprehensive RSpec tests
- Unit tests for all major classes and modules
- Integration tests with mocked AWS responses
- Test audio handling and streaming functionality
- Test tool calling integration
- Test error handling and edge cases
- Mock AWS Bedrock API calls using VCR or similar

### [ ] Step 8: Ensure Rubocop compliance
- Configure `.rubocop.yml` with appropriate rules
- Fix all style violations
- Ensure consistent code formatting
- Add documentation comments where needed

### [ ] Step 9: Create example usage and documentation
- Write comprehensive README with usage examples
- Document the suggested interface from the prompt
- Create example AudioHandler implementation using FFI::PortAudio
- Add YARD documentation for all public methods
- Include troubleshooting guide

### [ ] Step 10: Final testing and validation
- Run full test suite with `rspec`
- Ensure all tests pass with proper coverage
- Validate Rubocop compliance
- Test gem installation and basic functionality
- Verify integration with existing RubyLLM patterns

## Key Technical Requirements

### Dependencies
```ruby
# ruby-llm-speech.gemspec
spec.add_dependency "ruby_llm", "~> 1.3"
spec.add_dependency "aws-sdk-bedrockruntime", "~> 1.0"
spec.add_development_dependency "rspec", "~> 3.12"
spec.add_development_dependency "rubocop", "~> 1.0"
```

### Core API Design
```ruby
# Extend RubyLLM::Chat with speech capabilities
chat = RubyLLM.chat
  .with_model("amazon.nova-sonic-v1:0")
  .with_instructions("You are a friendly voice assistant.")
  .with_tool(TimeService)

# Audio handler (external to gem)
handler = AudioHandler.new

handler.on_audio_received do |audio_data|
  chat.send_audio(audio_data)
end

chat.on_audio_received do |audio|
  handler.play_audio(audio)
end

# Start speech conversation with transcript
chat.speak do |chunk|
  print chunk.content
end
```

### AWS Integration
- Use `invoke_model_with_bidirectional_stream` method
- Handle HTTP/2 streaming properly
- Implement proper error handling for AWS exceptions
- Support AWS credential configuration
- Region-specific endpoint handling

### Event Types to Handle
- `sessionStart` - Initialize conversation
- `audioInput` - Send user audio
- `textInput` - Send user text
- `audioOutput` - Receive model audio
- `textOutput` - Receive model text
- `contentStart`/`contentEnd` - Content boundaries
- `toolUse` - Function calling
- `completionEnd` - Conversation end

## Testing Strategy
- Mock AWS SDK calls to avoid real API usage during testing
- Test audio encoding/decoding functionality
- Unit test each component in isolation
- Integration tests for complete workflows
- Test error conditions and edge cases
- Test tool calling integration

## Success Criteria
- [ ] Gem installs without errors
- [ ] All RSpec tests pass
- [ ] Rubocop passes without violations
- [ ] Successfully extends RubyLLM::Chat class
- [ ] Supports Nova Sonic bidirectional streaming
- [ ] Handles audio input/output correctly
- [ ] Supports tool calling
- [ ] Provides clean, Ruby-like API
- [ ] Includes comprehensive documentation