lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "openehr_rails/version"

Gem::Specification.new do |gem|
  gem.name = "openehr-rails"
  gem.version = OpenehrRails::VERSION
  gem.platform = Gem::Platform::RUBY
  gem.authors = ["Shinji KOBAYASHI"]
  gem.email = "skoba@moss.gr.jp"

  gem.summary = "Rails extension for the openEHR archetypes"
  gem.description = "This product is a Rails extension for openEHR"
  gem.homepage = "http://openehr.jp"
  gem.license = "Apache-2.0"
  gem.extra_rdoc_files = [
    "README.md"
  ]
  gem.files         = `git ls-files`.split("\n")

  gem.metadata = {
    "source_code_uri" => "https://github.com/skoba/openehr-rails",
    "changelog_uri" => "https://github.com/skoba/openehr-rails/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/skoba/openehr-rails/issues",
    "rubygems_mfa_required" => "true"
  }

  gem.require_paths = ["lib"]
  gem.required_ruby_version = '>= 3.3.0'
  
  gem.add_dependency('openehr', '~> 2.0')
  gem.add_dependency('rails', '>= 7.0', '< 9.0')
  gem.add_dependency('nokogiri', '>= 1.10')
  
  gem.add_development_dependency('ammeter', '>= 1.1')
  gem.add_development_dependency('guard-rspec', '>= 4.7')
  # ostruct left Ruby's default gems as of 4.0; a couple of specs use
  # OpenStruct as a lightweight test double and need it declared explicitly.
  gem.add_development_dependency('ostruct')
  gem.add_development_dependency('rake')
  gem.add_development_dependency('rspec-rails', '>= 6.0')
  gem.add_development_dependency('rubocop-rails', '>= 2.20')
  gem.add_development_dependency('simplecov', '>= 0.21')
  gem.add_development_dependency('sqlite3', '>= 2.1')
  gem.add_development_dependency('webmock', '>= 3.19')
end
