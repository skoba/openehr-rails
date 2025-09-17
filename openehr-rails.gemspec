lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "openehr-rails/version"

Gem::Specification.new do |gem|
  gem.name = "openehr-rails"
  gem.version = OpenEHR::Rails::VERSION
  gem.platform = Gem::Platform::RUBY
  gem.authors = ["Shinji KOBAYASHI"]
  gem.email = "skoba@moss.gr.jp"

  gem.summary = "Rails extension for the openEHR archetypes"
  gem.description = "This product is a Rails extansion for openEHR"
  gem.homepage = "http://openehr.jp"
  gem.license = "Apache 2.0"
  gem.extra_rdoc_files = [
    "README.md"
  ]
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  gem.require_paths = ["lib"]
  gem.required_ruby_version = '>= 3.0.0'
  
  gem.add_dependency('openehr', '~> 1.3.0')
  gem.add_dependency('rails', '>= 7.0', '< 9.0')
  gem.add_dependency('ckm_client')
  gem.add_dependency('nokogiri', '>= 1.10')
  
  gem.add_development_dependency('rake')
  gem.add_development_dependency('ammeter', '>= 1.1')
  gem.add_development_dependency('rspec-rails', '>= 6.0')
  gem.add_development_dependency('rubocop-rails', '>= 2.20')
  gem.add_development_dependency('guard-rspec', '>= 4.7')
  gem.add_development_dependency('simplecov', '>= 0.21')
end
