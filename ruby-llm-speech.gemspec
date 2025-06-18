# frozen_string_literal: true

require_relative "lib/ruby_llm_speech/version"

Gem::Specification.new do |spec|
  spec.name          = "ruby-llm-speech"
  spec.version       = RubyLLMSpeech::VERSION
  spec.authors       = ["Ruby LLM Speech Contributors"]
  spec.email         = ["info@rubyllmspeech.org"]

  spec.summary       = "Speech functionality for RubyLLM using Amazon Nova Sonic"
  spec.description   = "Extends RubyLLM with speech capabilities using Amazon's Nova Sonic model " \
                       "through AWS Bedrock's bidirectional streaming API. Enables voice conversations " \
                       "with AI models including audio input/output and tool calling."
  spec.homepage      = "https://github.com/ruby-llm-speech/ruby-llm-speech"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ruby-llm-speech/ruby-llm-speech"
  spec.metadata["changelog_uri"] = "https://github.com/ruby-llm-speech/ruby-llm-speech/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/ruby-llm-speech/ruby-llm-speech/issues"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/ruby-llm-speech"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "ruby_llm", "~> 1.3"
  spec.add_dependency "aws-sdk-bedrockruntime", "~> 1.0"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "yard", "~> 0.9"
end