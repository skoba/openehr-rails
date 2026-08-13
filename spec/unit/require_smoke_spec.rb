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

# 'openehr-rails' (hyphenated) is what Bundler auto-requires in a host app's
# config/application.rb (Bundler.require(*Rails.groups) maps the gem name
# "openehr-rails" to `require 'openehr-rails'`), so it's the real entry
# point in practice, not just the underscored file. It used to also define
# an empty, unused `Openehr::Rails` module (leftover from a removed
# Railtie) -- guard against that reappearing, and confirm the version
# constant now lives on the real (flat) OpenehrRails module rather than
# the vestigial `OpenEHR::Rails` used only by the gemspec.
describe "'openehr-rails' (hyphenated) as Bundler would auto-require it" do
  it 'defines OpenehrRails::Engine and OpenehrRails::VERSION, and no stray Openehr constant' do
    root = File.expand_path('../..', __dir__)
    script = "require 'rails/all'; require 'openehr-rails'; " \
             "puts defined?(OpenehrRails::Engine) ? 'engine-yes' : 'engine-no'; " \
             "puts defined?(OpenehrRails::VERSION) ? \"version-\#{OpenehrRails::VERSION}\" : 'version-no'; " \
             "puts defined?(Openehr) ? 'openehr-stub-present' : 'openehr-stub-absent'"
    output = IO.popen(['bundle', 'exec', 'ruby', '-e', script], chdir: root, err: %i[child out], &:read)

    expect(output).to include('engine-yes'), "expected OpenehrRails::Engine to be defined; got:\n#{output}"
    expect(output).to include('version-'), "expected OpenehrRails::VERSION to be defined; got:\n#{output}"
    expect(output).to include('openehr-stub-absent'), "expected no stray Openehr constant; got:\n#{output}"
  end
end
