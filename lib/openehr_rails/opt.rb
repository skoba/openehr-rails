module OpenehrRails
  # OPT (Operational Template) parsing and introspection.
  module Opt
    # Parse an OPT file into an OpenEHR::AM::Template::OperationalTemplate.
    def self.parse(opt_file)
      Parser.new(opt_file).parse
    end
  end
end
