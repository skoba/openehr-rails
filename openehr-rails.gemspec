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
  gem.add_dependency('rake')
  gem.add_dependency('rails', '~> 4.0.0.beta1')
  gem.add_dependency('jquery-rails')
  gem.add_dependency('sqlite3')

  gem.add_dependency('sass-rails',   '~> 4.0.0.beta1')
  gem.add_dependency('coffee-rails', '~> 4.0.0.beta1')
  gem.add_dependency('uglifier', '>= 1.0.3')
  gem.add_dependency('turbolinks')

#  gem.add_development_dependency('cucumber')
#  gem.add_development_dependency('cucumber-rails')
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('rspec-rails')
  gem.add_development_dependency('guard')
  gem.add_development_dependency('guard-rspec', '~>2.4.0')
#  gem.add_development_dependency('guard-cucumber')
  gem.add_development_dependency('guard-livereload')
  gem.add_development_dependency('spork', '~> 1.0rc')
  gem.add_development_dependency('guard-spork')
  gem.add_development_dependency('database_cleaner')
  gem.add_development_dependency('simplecov')
  gem.add_development_dependency('listen', '0.6')
  gem.add_development_dependency('libnotify')
end