# -*- encoding: utf-8 -*-
# stub: ruby_llm 1.3.1 ruby lib

Gem::Specification.new do |s|
  s.name = "ruby_llm".freeze
  s.version = "1.3.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/crmne/ruby_llm/issues", "changelog_uri" => "https://github.com/crmne/ruby_llm/commits/main", "documentation_uri" => "https://rubyllm.com", "homepage_uri" => "https://rubyllm.com", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/crmne/ruby_llm" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Carmine Paolino".freeze]
  s.date = "1980-01-02"
  s.description = "A delightful Ruby way to work with AI. Tired of juggling different SDKs? RubyLLM provides one beautiful, Ruby-like interface for OpenAI, Anthropic, Gemini, Bedrock, OpenRouter, DeepSeek, Ollama, and any OpenAI-compatible API. Chat (with text, images, audio, PDFs), generate images, create embeddings, use tools (function calling), stream responses, and integrate with Rails effortlessly. Minimal dependencies, maximum developer happiness - just clean Ruby code that works.".freeze
  s.email = ["carmine@paolino.me".freeze]
  s.homepage = "https://rubyllm.com".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1.0".freeze)
  s.rubygems_version = "3.6.7".freeze
  s.summary = "A single delightful Ruby way to work with AI.".freeze

  s.installed_by_version = "3.6.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<base64>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<event_stream_parser>.freeze, ["~> 1".freeze])
  s.add_runtime_dependency(%q<faraday>.freeze, [">= 1.10.0".freeze])
  s.add_runtime_dependency(%q<faraday-multipart>.freeze, [">= 1".freeze])
  s.add_runtime_dependency(%q<faraday-net_http>.freeze, [">= 1".freeze])
  s.add_runtime_dependency(%q<faraday-retry>.freeze, [">= 1".freeze])
  s.add_runtime_dependency(%q<marcel>.freeze, ["~> 1.0".freeze])
  s.add_runtime_dependency(%q<zeitwerk>.freeze, ["~> 2".freeze])
end
