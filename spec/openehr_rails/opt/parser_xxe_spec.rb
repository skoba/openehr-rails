# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require 'tmpdir'

# #133 (R-20261128-13), regression pin: reading an OPT never resolves an
# external entity or loads an external DTD subset. Nokogiri's defaults already
# match the openehr gem's SAFE_PARSE_OPTIONS (no NOENT, no DTDLOAD, NONET);
# OpenehrRails::Opt::Parser now passes them by name, and these examples pin
# the result. Each payload is the real bmi_calculation.opt with a DOCTYPE added
# and an entity reference as its template_id (fixtures:
# spec/security_fixtures/README.md).
describe OpenehrRails::Opt::Parser do
  let(:fixtures) { File.expand_path('../../security_fixtures', __dir__) }
  let(:sentinel) { 'XXE-SENTINEL-CONTENT' }
  let(:bmi_opt) { File.read(File.expand_path('../../generators/templates/bmi_calculation.opt', __dir__)) }

  let(:entity_payload) do
    payload(%(<!DOCTYPE template [<!ENTITY xxe SYSTEM "file://#{fixtures}/xxe_sentinel.txt">]>), 'xxe')
  end
  let(:external_dtd_payload) do
    payload(%(<!DOCTYPE template SYSTEM "file://#{fixtures}/xxe_external_dtd.dtd">), 'leaked')
  end
  let(:unsafe) { Nokogiri::XML::ParseOptions::NOENT | Nokogiri::XML::ParseOptions::DTDLOAD }

  def payload(doctype, entity)
    bmi_opt.sub(/\A<\?xml[^>]*\?>/, %(<?xml version="1.0" encoding="UTF-8"?>\n#{doctype}))
           .sub('<value>bmi_calculation</value>', "<value>&#{entity};</value>")
  end

  # The payloads work: a parser that substitutes entities and loads DTDs reads
  # the sentinel, so the pins below would catch a regression.
  describe 'the payloads, read unsafely' do
    it 'leak the sentinel through an external entity' do
      doc = Nokogiri::XML(entity_payload, nil, nil, unsafe)

      expect(doc.remove_namespaces!.at('template_id value').text).to include(sentinel)
    end

    it 'leak the sentinel through an external DTD subset' do
      doc = Nokogiri::XML(external_dtd_payload, nil, nil, unsafe)

      expect(doc.remove_namespaces!.at('template_id value').text).to include(sentinel)
    end
  end

  # regression pin
  it 'passes the openehr gem SAFE_PARSE_OPTIONS to Nokogiri' do
    allow(Nokogiri::XML::Document).to receive(:parse).and_call_original

    OpenehrRails::Opt.parse(bmi_opt)

    expect(Nokogiri::XML::Document).to have_received(:parse)
      .with(anything, nil, nil, OpenEHR::Parser::Base::SAFE_PARSE_OPTIONS)
  end

  { 'an external entity' => :entity_payload, 'an external DTD subset' => :external_dtd_payload }
    .each do |label, payload_name|
    # regression pin: the entity is left unresolved, so the template has no
    # template_id and the reader refuses it, without the sentinel.
    it "does not read #{label}" do
      expect { OpenehrRails::Opt.parse(public_send(payload_name)) }
        .to raise_error(ArgumentError, /template_id is mandatory/) { |error| expect(error.message).not_to include(sentinel) }
    end

    # regression pin: the admin upload path refuses it (no template_id is
    # left) and registers nothing that holds the sentinel.
    it "keeps #{label} out of an upload" do
      Dir.mktmpdir do |root|
        path = File.join(root, 'attack.opt')
        File.write(path, public_send(payload_name))
        upload = Rack::Test::UploadedFile.new(path, 'application/xml')

        expect { OpenehrRails::TemplateUploader.call(file: upload, root: root) }
          .to raise_error(OpenehrRails::TemplateUploader::InvalidTemplate)
        expect(OpenehrTemplate.where('template_id LIKE ?', "%#{sentinel}%")).not_to exist
      end
    end
  end
end
