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
    "README.rdoc"
  ]
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  gem.require_paths = ["lib"]
  gem.add_dependency('openehr')
  gem.add_dependency('rails', '~> 4.0.0')
  gem.add_dependency('ckm_client')

  gem.add_development_dependency('rake')
  gem.add_development_dependency('ammeter')
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('rspec-rails')
  gem.add_development_dependency('simplecov')
end
