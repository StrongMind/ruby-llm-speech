#!/usr/bin/env ruby
# frozen_string_literal: true

# Weather Assistant Example
# This example shows voice interaction with tool calling capabilities

require_relative '../lib/ruby_llm_speech'

# Configure AWS credentials
RubyLLMSpeech.configure do |config|
  config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID'] || 'your_aws_access_key'
  config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || 'your_aws_secret_key'
  config.aws_region = ENV['AWS_REGION'] || 'us-east-1'
  config.default_voice = 'Amy'
  config.log_level = Logger::INFO
end

# Enhanced weather tool with more realistic data
class EnhancedWeatherTool
  class << self
    def description
      "Gets current weather information for any city worldwide"
    end

    def parameters
      {
        location: {
          type: "string",
          description: "The city and state/country for weather lookup (e.g., 'San Francisco, CA' or 'London, UK')",
          required: true
        }
      }
    end
  end

  def execute(location:)
    # Simulate realistic weather API response
    cities_weather = {
      "san francisco" => { temp: "65°F", condition: "Foggy", humidity: "78%", wind: "12 mph W" },
      "new york" => { temp: "72°F", condition: "Partly Cloudy", humidity: "65%", wind: "8 mph NE" },
      "london" => { temp: "58°F", condition: "Rainy", humidity: "85%", wind: "15 mph SW" },
      "tokyo" => { temp: "75°F", condition: "Sunny", humidity: "55%", wind: "6 mph E" },
      "miami" => { temp: "82°F", condition: "Thunderstorms", humidity: "90%", wind: "18 mph SE" },
      "seattle" => { temp: "62°F", condition: "Overcast", humidity: "72%", wind: "10 mph NW" }
    }

    # Normalize location for lookup
    normalized_location = location.downcase.split(',').first.strip

    weather_data = cities_weather[normalized_location] || {
      temp: "#{rand(45..85)}°F",
      condition: ["Sunny", "Cloudy", "Partly Cloudy", "Rainy", "Overcast"].sample,
      humidity: "#{rand(40..80)}%",
      wind: "#{rand(5..20)} mph #{['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'].sample}"
    }

    {
      location: location,
      temperature: weather_data[:temp],
      conditions: weather_data[:condition],
      humidity: weather_data[:humidity],
      wind: weather_data[:wind],
      timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      source: "Enhanced Weather Service"
    }
  end
end

# Voice-enabled weather assistant
class WeatherAssistant
  include RubyLLMSpeech::ChatExtension

  def initialize
    puts "🌤️  Weather Assistant with Voice"
    puts "=" * 40

    # Set up tools
    @weather_tool = EnhancedWeatherTool.new
    @calculator_tool = RubyLLMSpeech::ExampleTools::CalculatorTool.new
    @time_tool = RubyLLMSpeech::ExampleTools::TimeTool.new

    # Configure speech with weather-focused system prompt
    configure_speech(
      voice: 'Amy',
      temperature: 0.6,
      system_prompt: build_system_prompt,
      tools: [@weather_tool, @calculator_tool, @time_tool],
      transcript_enabled: true
    )

    puts "✅ Weather Assistant ready!"
    puts "🔊 Voice: Amy"
    puts "🛠️  Tools: Weather, Calculator, Time"
    puts "📋 Session: #{session_id}"
    puts
  end

  def demo_weather_queries
    puts "🌦️  Demo: Weather Queries"
    
    weather_questions = [
      "What's the weather like in San Francisco?",
      "How's the weather in London today?",
      "Tell me about the weather in Miami",
      "What's it like outside in Tokyo right now?"
    ]

    weather_questions.each_with_index do |question, index|
      puts "#{index + 1}. 🗣️  User: #{question}"
      
      begin
        speak(question)
        puts "   ✅ Processing with voice and tools..."
        
        # Show tool execution
        result = execute_tool_call("EnhancedWeatherTool", "execute", 
                                 { location: extract_location(question) })
        
        if result[:success]
          weather = result[:result]
          puts "   🌡️  Result: #{weather[:temperature]}, #{weather[:conditions]}"
          puts "   💨 Wind: #{weather[:wind]}, Humidity: #{weather[:humidity]}"
        else
          puts "   ❌ Tool execution failed: #{result[:error]}"
        end
        
      rescue StandardError => e
        puts "   ⚠️  Error: #{e.message}"
      end
      
      puts
      sleep(1)
    end
  end

  def demo_multi_tool_queries
    puts "🔧 Demo: Multi-Tool Queries"
    
    complex_questions = [
      "What time is it and what's the weather in New York?",
      "Calculate 25 times 4 and tell me about Seattle weather",
      "What's 15 plus 30, and how's the weather in London?"
    ]

    complex_questions.each_with_index do |question, index|
      puts "#{index + 1}. 🗣️  User: #{question}"
      
      begin
        speak(question)
        puts "   ✅ Processing multi-tool query..."
        
        # Demonstrate multiple tool calls
        if question.include?("time")
          time_result = execute_tool_call("TimeTool", "execute", {})
          puts "   ⏰ Time: #{time_result[:result][:formatted_time]}" if time_result[:success]
        end
        
        if question.include?("Calculate") || question.include?("plus") || question.include?("times")
          # Extract calculation from question
          calc_expr = extract_calculation(question)
          if calc_expr
            calc_result = execute_tool_call("CalculatorTool", "execute", { expression: calc_expr })
            puts "   🧮 Calculation: #{calc_expr} = #{calc_result[:result][:result]}" if calc_result[:success]
          end
        end
        
        if question.downcase.include?("weather")
          location = extract_location(question)
          weather_result = execute_tool_call("EnhancedWeatherTool", "execute", { location: location })
          if weather_result[:success]
            weather = weather_result[:result]
            puts "   🌤️  Weather: #{weather[:temperature]}, #{weather[:conditions]}"
          end
        end
        
      rescue StandardError => e
        puts "   ⚠️  Error: #{e.message}"
      end
      
      puts
      sleep(1)
    end
  end

  def demo_voice_configuration
    puts "🎛️  Demo: Voice Configuration"
    
    voices = ['Amy', 'Joanna', 'Matthew']
    
    voices.each do |voice|
      puts "Switching to voice: #{voice}"
      update_voice(voice)
      speak("Hello, I'm now speaking with the #{voice} voice.")
      puts "✅ Voice updated"
      sleep(1)
    end
    puts
  end

  def show_conversation_summary
    puts "📊 Conversation Summary"
    puts "=" * 40
    
    summary = get_transcript(format: :summary)
    if summary
      puts "Session ID: #{summary[:session_id]}"
      puts "Duration: #{summary[:duration].round(2)} seconds"
      puts "Total Messages: #{summary[:total_messages]}"
      puts "Tool Calls: #{summary[:tool_calls]}"
      puts "Last Activity: #{summary[:last_activity]}"
    end
    
    puts
    puts "🛠️  Available Tools:"
    list_tools.each { |tool| puts "  - #{tool}" }
    puts
  end

  def export_conversation
    puts "💾 Exporting Conversation"
    
    # Export to different formats
    filename_base = "weather_assistant_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
    
    begin
      export_transcript("#{filename_base}.txt", format: :text)
      puts "✅ Text transcript exported to #{filename_base}.txt"
      
      export_transcript("#{filename_base}.json", format: :json)
      puts "✅ JSON transcript exported to #{filename_base}.json"
      
    rescue StandardError => e
      puts "⚠️  Export failed: #{e.message}"
    end
    puts
  end

  def cleanup
    puts "🧹 Cleaning up..."
    close_voice_session
    puts "✅ Weather Assistant session closed"
  end

  private

  def build_system_prompt
    <<~PROMPT
      You are a helpful weather assistant with access to weather information tools.
      
      When users ask about weather, use the weather tool to get current conditions.
      When users ask for calculations, use the calculator tool.
      When users ask about time, use the time tool.
      
      Always be friendly and provide helpful, accurate information.
      Speak naturally as if you're having a conversation.
    PROMPT
  end

  def extract_location(question)
    # Simple location extraction (in production, you'd use NLP)
    cities = ["san francisco", "new york", "london", "tokyo", "miami", "seattle", "paris", "berlin"]
    
    question_lower = question.downcase
    detected_city = cities.find { |city| question_lower.include?(city) }
    detected_city || "Unknown Location"
  end

  def extract_calculation(question)
    # Simple calculation extraction
    if question.include?("times")
      # Extract "X times Y"
      matches = question.match(/(\d+)\s+times\s+(\d+)/)
      return "#{matches[1]} * #{matches[2]}" if matches
    elsif question.include?("plus")
      # Extract "X plus Y"
      matches = question.match(/(\d+)\s+plus\s+(\d+)/)
      return "#{matches[1]} + #{matches[2]}" if matches
    end
    
    nil
  end
end

# Main demo function
def main
  puts "🚀 Starting Weather Assistant Demo"
  puts

  begin
    assistant = WeatherAssistant.new
    
    # Run comprehensive demo
    assistant.demo_weather_queries
    assistant.demo_multi_tool_queries
    assistant.demo_voice_configuration
    assistant.show_conversation_summary
    assistant.export_conversation
    
    puts "🎉 Weather Assistant demo completed successfully!"
    
  rescue RubyLLMSpeech::ConfigurationError => e
    puts "❌ Configuration Error: #{e.message}"
    puts "💡 Make sure to set your AWS credentials:"
    puts "   export AWS_ACCESS_KEY_ID='your_key'"
    puts "   export AWS_SECRET_ACCESS_KEY='your_secret'"
    puts "   export AWS_REGION='us-east-1'"
    
  rescue RubyLLMSpeech::Error => e
    puts "❌ Error: #{e.message}"
    
  ensure
    assistant&.cleanup
  end
end

# Run the demo if this file is executed directly
main if __FILE__ == $PROGRAM_NAME