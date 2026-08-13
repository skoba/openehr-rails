# frozen_string_literal: true

require 'set'
require 'pathname'
require 'rubygems'

module OpenehrRails
  # Backs the `release:check` rake task (lib/tasks/release_check.rake).
  # Not required by lib/openehr_rails.rb -- this is a release-time dev
  # tool, not something a host app needs on every boot.
  #
  # Guards the specific pitfall this project's own history has actually
  # hit: `git add -A some/dir` stages the directory but not a sibling
  # `some/dir.rb` file, so a commit can silently ship a gem whose
  # `require 'some/dir'` finds nothing at runtime. This repo has exactly
  # that layout twice (lib/openehr_rails.rb + lib/openehr_rails/,
  # lib/openehr-rails.rb + lib/openehr-rails/), discovered the hard way
  # earlier in this project's history.
  class ReleaseCheck
    Failure = Struct.new(:message)

    def initialize(root: Dir.pwd)
      @root = root
    end

    def failures
      [
        *clean_working_tree_failures,
        *sibling_pair_failures,
        *gemspec_failures
      ]
    end

    def ok?
      failures.empty?
    end

    private

    def git(*args)
      out = IO.popen(['git', '-C', @root, *args], err: %i[child out], &:read)
      raise "git #{args.join(' ')} failed:\n#{out}" unless $?.success? # rubocop:disable Style/SpecialGlobalVars

      out
    end

    def tracked_files
      @tracked_files ||= git('ls-files').lines(chomp: true)
    end

    def clean_working_tree_failures
      status = git('status', '--porcelain')
      return [] if status.strip.empty?

      [Failure.new("working tree is not clean:\n#{status}")]
    end

    # Any lib/foo.rb with a same-named lib/foo/ directory is a
    # require-entry-point + implementation-dir pair (a common Ruby
    # layout); auto-detected rather than hardcoded so this also covers
    # any future sibling pair, not just the two known today.
    def sibling_pairs
      Dir.glob(File.join(@root, 'lib', '*.rb')).filter_map do |file|
        dir = file.delete_suffix('.rb')
        next unless Dir.exist?(dir)

        [relative(file), relative(dir)]
      end
    end

    def sibling_pair_failures
      tracked = tracked_files.to_set
      sibling_pairs.filter_map do |file, dir|
        next unless tracked.any? { |f| f.start_with?("#{dir}/") }
        next if tracked.include?(file)

        Failure.new(
          "#{file} exists as a sibling of tracked #{dir}/ but is not itself tracked by git " \
          '(classic `git add -A <dir>` pitfall -- `git add` the file explicitly)'
        )
      end
    end

    def gemspec_failures
      gemspec_path = Dir.glob(File.join(@root, '*.gemspec')).first
      return [Failure.new('no .gemspec found in the repo root')] unless gemspec_path

      spec = Dir.chdir(@root) { Gem::Specification.load(gemspec_path) }
      return [Failure.new("Gem::Specification.load(#{gemspec_path}) returned nil")] unless spec

      [
        *empty_files_failure(spec),
        *missing_sibling_in_gem_failures(spec),
        *license_failures(spec),
        *validate_failure(spec)
      ]
    end

    def empty_files_failure(spec)
      return [] unless spec.files.empty?

      [Failure.new('gem.files is empty -- gemspec probably ran `git ls-files` outside a git repo')]
    end

    def missing_sibling_in_gem_failures(spec)
      sibling_pairs.filter_map do |file, dir|
        next unless spec.files.any? { |f| f.start_with?("#{dir}/") }
        next if spec.files.include?(file)

        Failure.new("#{file} is tracked by git but missing from gem.files (the built gem would omit it)")
      end
    end

    # Gem::Specification#validate only *warns* (to stdout) on an invalid
    # SPDX identifier; it doesn't fail the build, so a typo-like "Apache
    # 2.0" (not valid SPDX; the real one is "Apache-2.0") silently ships.
    def license_failures(spec)
      spec.licenses.reject { |license| Gem::Licenses.match?(license) }.map do |license|
        Failure.new("#{license.inspect} is not a valid SPDX license identifier (see https://spdx.org/licenses)")
      end
    end

    def validate_failure(spec)
      Dir.chdir(@root) { spec.validate }
      []
    rescue StandardError => e
      [Failure.new("gemspec failed Gem::Specification#validate: #{e.message}")]
    end

    def relative(path)
      Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
    end
  end
end
