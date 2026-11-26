# frozen_string_literal: true

require 'spec_helper'

# Issue #74 (plan docs/design/0.9.x-plan.md 4): the gem ships what a host
# application runs, not the repo's specs, docs and tooling.
describe 'openehr-rails.gemspec files' do # rubocop:disable RSpec/DescribeClass -- packaging, no class under test
  let(:root) { File.expand_path('../..', __dir__) }
  let(:files) { Dir.chdir(root) { Gem::Specification.load('openehr-rails.gemspec').files } }
  let(:tracked) { Dir.chdir(root) { `git ls-files -z`.split("\0") } }

  # enhancement: red before #74 (gem.files was every tracked file).
  it 'ships no spec/, docs or tooling files' do
    excluded = %w[spec/ docs/ doc/ demo_assets/ script/ gemfiles/ docker/ .github/ .devcontainer/]
    expect(files.select { |file| file.start_with?(*excluded) }).to eq([])
    expect(files & %w[CLAUDE.md Gemfile Rakefile Guardfile .rubocop.yml]).to eq([])
  end

  # regression pin: everything the engine and the generators read at runtime.
  it 'ships every tracked file under lib/, app/ and config/, generator templates included' do
    runtime = tracked.select { |file| file.start_with?('lib/', 'app/', 'config/') }

    expect(runtime.grep(%r{\Alib/generators/.+/templates/})).not_to be_empty
    expect(runtime - files).to eq([])
  end

  # regression pin
  it 'ships README.md, CHANGELOG.md and LICENSE' do
    expect(files).to include('README.md', 'CHANGELOG.md', 'LICENSE')
  end
end
