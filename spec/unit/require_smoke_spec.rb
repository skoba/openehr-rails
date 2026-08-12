# frozen_string_literal: true

require 'spec_helper'

# `require 'openehr_rails'` is the gem's real public entry point in a host
# app; spec/support/active_record.rb (loaded by spec_helper for every other
# spec in this suite) independently requires 'openehr_rails/rm', which was
# masking the fact that lib/openehr_rails.rb itself never required it -- so
# OpenehrRails::Rm was undefined in any real app, silently disabling the RM
# graph persistence layer (Storable#rm_layer_available? uses `defined?` as
# its guard and degrades quietly rather than raising). Exercise the require
# in a clean subprocess so this can't be masked by another support file.
describe "'openehr_rails' as a real host app would load it" do
  it 'defines OpenehrRails::Rm' do
    root = File.expand_path('../..', __dir__)
    # A real Rails app loads ActiveRecord (via rails/all + Bundler.require)
    # before requiring this gem's default file; replicate that order here
    # rather than the bare `require 'openehr_rails'` this bug hides behind.
    script = "require 'active_record'; require 'openehr_rails'; " \
             "puts defined?(OpenehrRails::Rm) ? 'yes' : 'no'"
    output = IO.popen(['bundle', 'exec', 'ruby', '-e', script], chdir: root, err: %i[child out], &:read)

    expect(output).to include('yes'), "expected OpenehrRails::Rm to be defined; got:\n#{output}"
  end
end
