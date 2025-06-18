You are a master Ruby engineer.
Your goal is to create a beautiful gem called ruby-llm-speech that relies on patterns set in the gem located at https://github.com/crmne/ruby_llm

** Gem Design **
1. Depends on the following gems:
  - ruby_llm
  - aws-sdk-bedrockruntime
2. Extends the RubyLLM.chat class to add a #speak method
3. Uses the RubyLLM::Tool class to call tools
4. Fully tested with RSpec
5. Fully compliant with the latest rubocop rules

** Functional Requirements **
1. Supports the amazon.nova-sonic-v1:0 model
2. Uses the invoke_model_with_bidirectional_stream method on the aws-sdk-bedrockruntime SDK.
3. Enables users to interface with Nova Sonic using their spoken voice and hear the responses as well as see a running transcript of the conversation.
4. Supports setting the system prompt.
5. Supports changing the voice.
6. Supports tool calling.

** Suggested Interface **
```ruby

# These pieces are already built-in to RubyLLM
class Time < RubyLLM::Tool
    description "Gets the current time"

    def execute
        Time.current.strftime("%H:%M:%S")
    end

chat = RubyLLM.chat
chat.with_model("amazon.nova-sonic-v1:0") 
chat.with_tool(Time)
chat.with_instructions("You are a friend who is ready to speak with the user audibly.")

# This is new

# AudioRecorder is a made up class that is not part of the gem, but could be included in a sample console app that uses FFI::PortAudio
handler = AudioHandler.new 

handler.on_audio_received do |audio_data|
    # Send recorded audio from the user to the model
    chat.send_audio(audio_data)
end

chat.on_audio_received do |audio|
    # Play the audio received from the model back to the user
    handler.play_audio(audio)
end

# Start the conversation and print the transcript of the conversation
chat.speak do |chunk|
    print chunk.content
end

```

** Sample Guidance for Reference **
Use the following working sample as a guide to your implementation: 
- https://github.com/StrongMind/central/blob/main/app/services/nova_sonic/audio_service.rb
- https://github.com/StrongMind/central/blob/main/app/channels/audio_stream_channel/nova_sonic_audio_handler.rb
- https://github.com/StrongMind/central/blob/main/app/channels/audio_stream_channel/nova_sonic_event_handler.rb

** Instructions **

1. Build a detailed plan and write the plan into a file called plan.md
    The plan.md file should contain the steps needed to accomplish the overall goal like this (this is just an example, not the real steps):
    [ ] Step 1: Create gemspec file
    [ ] Step 2: Create wrapper for Nova Sonic
    [ ] Step 3: Create specs
    [ ] Step 4: Ensure code and specs pass rubocop
    [ ] Step 5: Ensure all specs are passing

2. Ask me clarifying questions to validate your assumptions.
3. Once the plan is solid, get me to review it before continuing.
4. Take each step one at a time and mark it done in plan.md as you go.
    Like this:
    [x] Step 1: Create gemspec file
    [ ] Step 2: Create wrapper for Nova Sonic
    [ ] Step 3: Create specs
    [ ] Step 4: Ensure code and specs pass rubocop
    [ ] Step 5: Ensure all specs are passing

