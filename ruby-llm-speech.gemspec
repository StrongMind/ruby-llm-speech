# frozen_string_literal: true

require_relative "lib/ruby_llm_speech/version"

Gem::Specification.new do |spec|
  spec.name        = "ruby-llm-speech"
  spec.version     = RubyLLMSpeech::VERSION
  spec.summary     = "Voice interactions for RubyLLM using Amazon Nova Sonic"
  spec.description = <<~DESC
    Extends RubyLLM to add voice interaction capabilities using Amazon Nova Sonic.
    Enables users to interface with Nova Sonic using their spoken voice and hear
    the responses as well as see a running transcript of the conversation.
  DESC
  spec.authors     = ["Ruby LLM Speech Team"]

  spec.license  = "MIT"
  spec.homepage = "https://github.com/ruby-llm/ruby-llm-speech"
  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/ruby-llm/ruby-llm-speech/issues",
    "changelog_uri"     => "https://github.com/ruby-llm/ruby-llm-speech/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/ruby-llm-speech",
    "homepage_uri"      => spec.homepage,
    "source_code_uri"   => "https://github.com/ruby-llm/ruby-llm-speech"
  }

  spec.files = Dir["lib/**/*"]

  spec.required_ruby_version = ">= 3.0.0"

  spec.add_dependency "ruby_llm", "~> 1.3"
  spec.add_dependency "aws-sdk-bedrockruntime", "~> 1.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end