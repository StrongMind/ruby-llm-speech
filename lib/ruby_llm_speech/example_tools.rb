# frozen_string_literal: true

module RubyLLMSpeech
  module ExampleTools
    # Example weather tool for voice interactions
    class WeatherTool
      class << self
        def description
          "Gets current weather information for a specified location"
        end

        def parameters
          {
            location: {
              type: "string",
              description: "The city and state/country for weather lookup",
              required: true
            }
          }
        end
      end

      def execute(location:)
        # Simulate weather API call
        {
          location: location,
          temperature: "#{rand(60..85)}°F",
          conditions: ["sunny", "cloudy", "partly cloudy", "rainy"].sample,
          humidity: "#{rand(30..70)}%",
          timestamp: Time.now.to_s
        }
      end

      def get_current_weather(location:)
        execute(location: location)
      end
    end

    # Example calculator tool for voice interactions
    class CalculatorTool
      class << self
        def description
          "Performs basic mathematical calculations"
        end

        def parameters
          {
            expression: {
              type: "string", 
              description: "Mathematical expression to evaluate (e.g., '2 + 2', '10 * 5')",
              required: true
            }
          }
        end
      end

      def execute(expression:)
        # Simple and safe calculation
        # In production, you'd want to use a proper math parser
        begin
          # Only allow basic mathematical operations for safety
          if expression.match?(/\A[\d\s+\-*\/\(\)\.]+\z/)
            result = eval(expression)
            {
              expression: expression,
              result: result,
              timestamp: Time.now.to_s
            }
          else
            {
              error: "Invalid mathematical expression",
              expression: expression
            }
          end
        rescue StandardError => e
          {
            error: "Calculation error: #{e.message}",
            expression: expression
          }
        end
      end

      def calculate(expression:)
        execute(expression: expression)
      end
    end

    # Example time tool for voice interactions
    class TimeTool
      class << self
        def description
          "Provides current time and date information"
        end

        def parameters
          {
            timezone: {
              type: "string",
              description: "Timezone (optional, defaults to system timezone)",
              required: false
            }
          }
        end
      end

      def execute(timezone: nil)
        current_time = Time.now
        
        # Simple timezone handling - in production you'd use a proper timezone library
        if timezone && timezone.downcase.include?("utc")
          current_time = current_time.utc
        end

        {
          current_time: current_time.strftime("%Y-%m-%d %H:%M:%S"),
          timezone: timezone || "Local",
          day_of_week: current_time.strftime("%A"),
          formatted_time: current_time.strftime("%I:%M %p"),
          timestamp: current_time.to_f
        }
      end

      def get_current_time(timezone: nil)
        execute(timezone: timezone)
      end

      def get_date
        {
          date: Time.now.strftime("%Y-%m-%d"),
          formatted_date: Time.now.strftime("%B %d, %Y"),
          day_of_week: Time.now.strftime("%A")
        }
      end
    end
  end
end