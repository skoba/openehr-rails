# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# #94 (R-20261127-2): the AQL console view renders the prefilled values
# escaped, and opening it never runs the query.
# rubocop:disable-next RSpec/DescribeClass -- renders the engine's ERB view; there is no view class
describe 'AQL console view (#94)' do
  def render_console(params = {})
    view = ActionView::Base.with_empty_template_cache.with_view_paths(
      [File.expand_path('../../app/views', __dir__)]
    )
    view.define_singleton_method(:templates_path) { '/openehr/templates' }
    view.define_singleton_method(:ehrs_path) { '/openehr/ehrs' }
    view.define_singleton_method(:query_aql_path) { '/openehr/v1/query/aql' }
    view.assign(prefill: OpenehrRails::QueryConsolePrefill.new(params))
    view.render(template: 'openehr_rails/queries/show')
  end

  def textarea(html)
    html[%r{<textarea id="aql-query"[^>]*>(.*?)</textarea>}m, 1]
  end

  it 'puts q into the query textarea' do # enhancement
    html = render_console(q: 'SELECT c FROM EHR e[ehr_id/value=$ehr_id] CONTAINS COMPOSITION c')

    expect(textarea(html)).to eq('SELECT c FROM EHR e[ehr_id/value=$ehr_id] CONTAINS COMPOSITION c')
  end

  it 'puts query_parameters into the parameters input' do # enhancement
    html = render_console(query_parameters: '{"ehr_id":"e-1"}')

    expect(html).to include('value="{&quot;ehr_id&quot;:&quot;e-1&quot;}"')
  end

  it 'escapes a q that tries to close the textarea' do # enhancement
    html = render_console(q: '</textarea><script>alert(1)</script>')

    expect(html).to include('&lt;/textarea&gt;&lt;script&gt;alert(1)&lt;/script&gt;')
    expect(html).not_to include('<script>alert(1)')
  end

  it 'shows the notice when a value is over the limit' do # enhancement
    html = render_console(q: 'x' * (OpenehrRails::QueryConsolePrefill::MAX_LENGTH + 1))

    expect(html).to include(OpenehrRails::QueryConsolePrefill::MAX_LENGTH.to_s)
  end

  it 'renders the example query and an empty parameters input without parameters' do # regression pin
    html = render_console

    expect(textarea(html)).to eq(<<~AQL.chomp)
      SELECT o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude AS height
      FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2]
    AQL
    expect(html).to match(/<input id="aql-params" type="text"[^>]*placeholder='{"min": 100}'>/)
  end

  it 'runs the query only from the button' do # regression pin: opening the page does not execute
    script = render_console(q: 'SELECT c FROM EHR e CONTAINS COMPOSITION c')[%r{<script>(.*)</script>}m, 1]

    expect(script.scan('fetch(').size).to eq(1)
    expect(script[/runButton\.addEventListener\('click', function \(\) \{(.*)\}\);\s*\}\)\(\);/m, 1]).to include('fetch(')
  end
end
