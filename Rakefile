#!/usr/bin/env rake
# encoding: utf-8
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require 'rubygems'
require 'bundler'
require "bundler/gem_tasks"
require 'rake'
require 'rspec/core'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
  # Load Bundler's gem set in the spawned rspec process before anything
  # else, so `rake spec` works without an explicit `bundle exec`: the
  # development-only gems (e.g. ammeter) land on the load path and the
  # Gemfile.lock versions win over conflicting default gems like erb.
  spec.ruby_opts = '-rbundler/setup'
end

task :default => :spec

