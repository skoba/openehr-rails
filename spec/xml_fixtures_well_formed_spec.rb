# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

# R-20261128-13: every tracked XML fixture (OPTs and any other *.xml under
# spec/ and demo_assets/) is well-formed XML 1.0, i.e. Nokogiri reads it in
# STRICT mode. The usual readers parse with RECOVER and accept a fixture that
# a strict XML tool refuses: two OPTs here had `--` in their leading comment,
# which XML 1.0 section 2.5 does not allow. No file is excluded.
module XmlFixtures
  ROOT = File.expand_path('..', __dir__)
  FILES = Dir.chdir(ROOT) { `git ls-files -z -- '*.opt' '*.xml'`.split("\x0") }.freeze
end

describe 'tracked XML fixtures' do # rubocop:disable RSpec/DescribeClass -- fixture files, no class under test
  it 'finds tracked XML fixtures' do
    expect(XmlFixtures::FILES).not_to be_empty
  end

  XmlFixtures::FILES.each do |file|
    # bug: red before R-20261128-13 for the two OPTs whose comments held `--`;
    # regression pin for the rest.
    it "reads #{file} in STRICT mode (well-formed)" do
      source = File.read(File.join(XmlFixtures::ROOT, file))

      expect { Nokogiri::XML.parse(source) { |config| config.strict.nonet } }.not_to raise_error
    end
  end
end
