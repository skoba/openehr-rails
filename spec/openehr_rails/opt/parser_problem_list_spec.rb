require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Opt::Parser do
  describe 'with problem_list.opt (issue #30, dependency-floor prerequisite)' do
    # regression pin: fixture parseability, not new behavior -- this pins that
    # the openehr dependency floor raise (>= 2.3.1) actually fixes what it
    # claims to fix, not a red-then-green spec for FieldExtractor/ProfileGenerator
    # behavior (those specs live elsewhere and cover the actual issue #30 fix)
    let(:opt_file) { File.expand_path('../../templates/problem_list.opt', __dir__) }

    it 'parses without raising (C_CODE_REFERENCE support requires openehr >= 2.3.1, skoba/openehr-ruby#30)' do
      expect { OpenehrRails::Opt.parse(opt_file) }.not_to raise_error
    end
  end
end
