# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "alterity/version"

Gem::Specification.new do |spec|
  spec.name = "alterity"
  spec.version = Alterity::VERSION
  spec.authors = ["Chris Maximin"]
  spec.email = ["gems@chrismaximin.com"]
  spec.licenses = ["MIT"]

  spec.summary = "Execute your ActiveRecord migrations with Percona's pt-online-schema-change."
  spec.description = spec.summary
  spec.homepage = "https://github.com/gumroad/alterity"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gumroad/alterity"
  spec.metadata["changelog_uri"] = "https://github.com/gumroad/alterity/blob/master/CHANGELOG.md"

  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 2.7"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").select { |f| f.match(%r{^(lib)/}) }
  end
  spec.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.10"

  spec.add_runtime_dependency "mysql2", ">= 0.3"
  spec.add_runtime_dependency "rails", ">= 5"
end
