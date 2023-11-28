# frozen_string_literal: true

require_relative "lib/db_before_after/version"

Gem::Specification.new do |spec|
  spec.name = "db_before_after"
  spec.version = DbBeforeAfter::VERSION
  spec.authors = ["iwazzer"]
  spec.email = ["eiji.iwazawa@hacomono.co.jp"]

  spec.summary = "A tool to visualize how the database changes before and after a use case is executed."
  spec.description = "A tool to visualize how the database changes before and after a use case is executed."
  spec.homepage = "https://github.com/iwazzer/db_before_after"
  spec.required_ruby_version = ">= 2.7.5"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency 'diffy'
  spec.add_dependency 'ulid'
  spec.add_dependency 'mysql2'
  spec.add_dependency 'clipboard'

  spec.add_development_dependency 'bundler', '~> 2.2'
  spec.add_development_dependency 'byebug'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
