# frozen_string_literal: true

require 'spec_helper'

# R-20261127-28: README.md (English) is the main text and README.ja.md its
# Japanese translation. A PR that changes README.md fixes README.ja.md in the
# same PR (CLAUDE.md). regression pin: this keeps the two side by side; it
# does not judge the translation itself.
describe 'README translation' do # rubocop:disable RSpec/DescribeClass -- documentation, no class under test
  let(:root) { File.expand_path('../..', __dir__) }
  let(:english) { File.read(File.join(root, 'README.md')) }
  let(:japanese) { File.read(File.join(root, 'README.ja.md')) }

  # Markdown headings, skipping fenced code blocks (whose `#` lines are comments).
  def headings(text)
    in_code = false
    text.each_line.filter_map do |line|
      in_code = !in_code if line.start_with?('```')
      line[/\A#+(?= )/] unless in_code
    end
  end

  it 'has a non-empty English and Japanese README' do
    expect(english.strip).not_to be_empty
    expect(japanese.strip).not_to be_empty
  end

  it 'links each version to the other in its first line' do
    expect(english.lines.first.chomp).to eq('English | [日本語](README.ja.md)')
    expect(japanese.lines.first.chomp).to eq('[English](README.md) | 日本語')
  end

  it 'says in the Japanese version that the English version prevails' do
    expect(japanese).to include('英語版の訳です。食い違うときは、英語版が正です。')
  end

  it 'has the same headings, level by level, in both versions' do
    expect(headings(japanese)).to eq(headings(english))
  end

  it 'keeps the Japanese version out of the gem' do
    files = Dir.chdir(root) { Gem::Specification.load('openehr-rails.gemspec').files }
    expect(files).not_to include('README.ja.md')
  end
end
