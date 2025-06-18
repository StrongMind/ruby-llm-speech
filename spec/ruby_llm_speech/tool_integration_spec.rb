# frozen_string_literal: true

RSpec.describe "Tool Integration" do
  let(:mock_chat_class) do
    Class.new do
      include RubyLLMSpeech::ChatExtension
    end
  end

  let(:chat_instance) { mock_chat_class.new }
  let(:weather_tool) { RubyLLMSpeech::ExampleTools::WeatherTool.new }
  let(:calculator_tool) { RubyLLMSpeech::ExampleTools::CalculatorTool.new }

  before do
    RubyLLMSpeech.configure do |config|
      config.aws_access_key_id = "test_key"
      config.aws_secret_access_key = "test_secret"
    end
  end

  describe "tool configuration" do
    it "configures tools during speech setup" do
      chat_instance.configure_speech(tools: [weather_tool, calculator_tool])

      expect(chat_instance.speech_tools).to include(weather_tool)
      expect(chat_instance.speech_tools).to include(calculator_tool)
    end

    it "configures empty tools array by default" do
      chat_instance.configure_speech

      expect(chat_instance.speech_tools).to eq([])
    end
  end

  describe "#add_tool" do
    before do
      chat_instance.configure_speech
    end

    it "adds a tool to the speech tools collection" do
      result = chat_instance.add_tool(weather_tool)

      expect(result).to eq(chat_instance)
      expect(chat_instance.speech_tools).to include(weather_tool)
    end

    it "updates nova sonic client with new tool" do
      expect(chat_instance.nova_sonic_client).to receive(:add_tool).with(weather_tool)

      chat_instance.add_tool(weather_tool)
    end
  end

  describe "#remove_tool" do
    before do
      chat_instance.configure_speech(tools: [weather_tool, calculator_tool])
    end

    it "removes a tool from the speech tools collection" do
      result = chat_instance.remove_tool("WeatherTool")

      expect(result).to eq(chat_instance)
      expect(chat_instance.speech_tools).not_to include(weather_tool)
      expect(chat_instance.speech_tools).to include(calculator_tool)
    end

    it "updates nova sonic client to remove tool" do
      expect(chat_instance.nova_sonic_client).to receive(:remove_tool).with("WeatherTool")

      chat_instance.remove_tool("WeatherTool")
    end
  end

  describe "#list_tools" do
    it "returns empty array when no tools configured" do
      chat_instance.configure_speech

      expect(chat_instance.list_tools).to eq([])
    end

    it "returns tool class names" do
      chat_instance.configure_speech(tools: [weather_tool, calculator_tool])

      tool_names = chat_instance.list_tools
      expect(tool_names).to include("RubyLLMSpeech::ExampleTools::WeatherTool")
      expect(tool_names).to include("RubyLLMSpeech::ExampleTools::CalculatorTool")
    end
  end

  describe "#with_tool" do
    before do
      chat_instance.configure_speech
    end

    it "adds a tool and returns self for chaining" do
      result = chat_instance.with_tool(weather_tool)

      expect(result).to eq(chat_instance)
      expect(chat_instance.speech_tools).to include(weather_tool)
    end
  end

  describe "#with_tools" do
    before do
      chat_instance.configure_speech
    end

    it "adds multiple tools and returns self for chaining" do
      result = chat_instance.with_tools(weather_tool, calculator_tool)

      expect(result).to eq(chat_instance)
      expect(chat_instance.speech_tools).to include(weather_tool)
      expect(chat_instance.speech_tools).to include(calculator_tool)
    end
  end

  describe "#execute_tool_call" do
    before do
      chat_instance.configure_speech(tools: [weather_tool, calculator_tool])
    end

    it "executes a tool successfully" do
      result = chat_instance.execute_tool_call("WeatherTool", "execute", { location: "New York" })

      expect(result[:success]).to be true
      expect(result[:result]).to have_key(:location)
      expect(result[:result][:location]).to eq("New York")
    end

    it "returns error for non-existent tool" do
      result = chat_instance.execute_tool_call("NonexistentTool", "execute", {})

      expect(result[:error]).to eq("Tool not found: NonexistentTool")
    end

    it "handles tool execution errors" do
      allow(weather_tool).to receive(:execute).and_raise(StandardError, "API error")

      result = chat_instance.execute_tool_call("WeatherTool", "execute", { location: "New York" })

      expect(result[:error]).to eq("Tool execution failed: API error")
    end
  end

  describe "example tools" do
    describe "WeatherTool" do
      it "has proper class methods" do
        expect(RubyLLMSpeech::ExampleTools::WeatherTool.description).to be_a(String)
        expect(RubyLLMSpeech::ExampleTools::WeatherTool.parameters).to have_key(:location)
      end

      it "executes weather lookup" do
        result = weather_tool.execute(location: "San Francisco")

        expect(result).to have_key(:location)
        expect(result).to have_key(:temperature)
        expect(result).to have_key(:conditions)
        expect(result[:location]).to eq("San Francisco")
      end
    end

    describe "CalculatorTool" do
      it "has proper class methods" do
        expect(RubyLLMSpeech::ExampleTools::CalculatorTool.description).to be_a(String)
        expect(RubyLLMSpeech::ExampleTools::CalculatorTool.parameters).to have_key(:expression)
      end

      it "executes basic calculations" do
        result = calculator_tool.execute(expression: "2 + 2")

        expect(result).to have_key(:expression)
        expect(result).to have_key(:result)
        expect(result[:result]).to eq(4)
      end

      it "handles invalid expressions" do
        result = calculator_tool.execute(expression: "invalid_expression")

        expect(result).to have_key(:error)
        expect(result[:error]).to include("Invalid mathematical expression")
      end
    end

    describe "TimeTool" do
      let(:time_tool) { RubyLLMSpeech::ExampleTools::TimeTool.new }

      it "has proper class methods" do
        expect(RubyLLMSpeech::ExampleTools::TimeTool.description).to be_a(String)
        expect(RubyLLMSpeech::ExampleTools::TimeTool.parameters).to have_key(:timezone)
      end

      it "provides current time information" do
        result = time_tool.execute

        expect(result).to have_key(:current_time)
        expect(result).to have_key(:day_of_week)
        expect(result).to have_key(:formatted_time)
      end

      it "provides date information" do
        result = time_tool.get_date

        expect(result).to have_key(:date)
        expect(result).to have_key(:formatted_date)
        expect(result).to have_key(:day_of_week)
      end
    end
  end
end