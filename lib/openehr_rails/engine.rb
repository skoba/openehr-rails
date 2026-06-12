# frozen_string_literal: true

module OpenehrRails
  # Admin engine: mount OpenehrRails::Engine => '/openehr' exposes the
  # template management UI (drag & drop OPT upload + runtime scaffolding).
  class Engine < ::Rails::Engine
    isolate_namespace OpenehrRails
  end
end
