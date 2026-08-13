# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails/release_check'
require 'tmpdir'
require 'fileutils'

GEMSPEC_BODY = <<~RUBY
  Gem::Specification.new do |s|
    s.name = 'fixture'
    s.version = '0.1.0'
    s.summary = 'fixture gem'
    s.authors = ['Test']
    s.license = 'Apache-2.0'
    s.files = `git ls-files`.split("\\n")
  end
RUBY

describe OpenehrRails::ReleaseCheck do
  around do |example|
    Dir.mktmpdir do |dir|
      @repo = dir
      git('init', '-q')
      git('config', 'user.email', 'test@example.com')
      git('config', 'user.name', 'Test')
      example.run
    end
  end

  def write(path, content)
    full = File.join(@repo, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def git(*args)
    Dir.chdir(@repo) { system('git', *args, exception: true) }
  end

  it 'passes for a clean repo with fully-tracked sibling files' do
    write('fixture.gemspec', GEMSPEC_BODY)
    write('lib/foo.rb', "module Foo\nend\n")
    write('lib/foo/bar.rb', "module Foo\n  module Bar\n  end\nend\n")
    git('add', '-A')
    git('commit', '-q', '-m', 'init')

    expect(described_class.new(root: @repo).failures).to eq([])
  end

  it 'flags a sibling file left untracked by a directory-scoped `git add` (the historical pitfall)' do
    write('fixture.gemspec', GEMSPEC_BODY)
    write('lib/foo.rb', "module Foo\nend\n")
    write('lib/foo/bar.rb', "module Foo\n  module Bar\n  end\nend\n")
    git('add', 'fixture.gemspec', 'lib/foo') # stages the dir, NOT the sibling lib/foo.rb
    git('commit', '-q', '-m', 'partial commit')

    messages = described_class.new(root: @repo).failures.map(&:message).join("\n")

    expect(messages).to match(%r{lib/foo\.rb.*not.*tracked}m)
  end

  it 'flags a dirty working tree' do
    write('fixture.gemspec', GEMSPEC_BODY)
    git('add', '-A')
    git('commit', '-q', '-m', 'init')
    write('untracked.txt', 'oops')

    messages = described_class.new(root: @repo).failures.map(&:message).join("\n")

    expect(messages).to match(/working tree is not clean/)
  end

  it 'flags a gemspec with an invalid SPDX license identifier' do
    write('fixture.gemspec', GEMSPEC_BODY.sub("'Apache-2.0'", "'Apache 2.0'"))
    git('add', '-A')
    git('commit', '-q', '-m', 'init')

    messages = described_class.new(root: @repo).failures.map(&:message).join("\n")

    expect(messages).to match(/valid SPDX license/)
  end
end
