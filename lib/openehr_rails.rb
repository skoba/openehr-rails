require 'uri'

# Workaround for Ruby 3.4 URI compatibility
begin
  URI.class_variable_get(:@@schemes)
rescue NameError
  URI.class_variable_set(:@@schemes, {})
end

require 'openehr/am'
require 'openehr/rm'
require 'openehr/parser'

require 'openehr_rails/opt'
require 'openehr_rails/opt/parser'
require 'openehr_rails/opt/field_extractor'
require 'openehr_rails/storable'
require 'openehr_rails/aql_queryable'
require 'openehr_rails/template_registry'

module OpenehrRails
end
