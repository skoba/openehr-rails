# frozen_string_literal: true

require_relative '../openehr_rails/release_check'

namespace :release do
  desc 'Pre-release sanity checks: clean working tree, sibling-file tracking, gemspec validity'
  task :check do
    failures = OpenehrRails::ReleaseCheck.new.failures

    if failures.empty?
      puts 'release:check OK'
    else
      failures.each { |failure| warn "release:check FAILED: #{failure.message}" }
      abort "release:check found #{failures.size} problem(s)"
    end
  end
end
