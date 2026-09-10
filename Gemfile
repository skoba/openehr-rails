source 'https://rubygems.org'

gemspec

# json 3.0 (released 2026-09-09) changed JSON.parse's arity; ActiveSupport::JSON.decode
# as of activesupport 8.1.3.1 still passes its options positionally, so reading any
# json column raises ArgumentError (wrong number of arguments (given 2, expected 1)).
# Dev/test-only pin -- the gemspec is untouched, host apps resolve their own json.
# Drop once a Rails patch release carries the fix (docs/backlog.md, "Dependencies").
gem 'json', '< 3'
