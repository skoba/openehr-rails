# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require 'tmpdir'

describe OpenehrRails::TemplateUploader do
  let(:opt_path) do
    File.expand_path('../generators/templates/bmi_calculation.opt', __dir__)
  end
  let(:upload) do
    Rack::Test::UploadedFile.new(opt_path, 'application/xml')
  end

  around do |example|
    Dir.mktmpdir { |dir| @root = Pathname.new(dir); example.run }
  end

  it 'stores the OPT under app/templates/operational and registers it' do
    record = described_class.call(file: upload, root: @root)

    expect(@root.join('app/templates/operational/bmi_calculation.opt')).to exist
    expect(record.template_id).to eq('bmi_calculation')
    expect(record.template_type).to eq('operational_template')
    expect(OpenehrTemplate.where(template_id: 'bmi_calculation').count).to eq(1)
  end

  it 'is idempotent for the same template' do
    described_class.call(file: upload, root: @root)
    expect { described_class.call(file: upload, root: @root) }
      .not_to change(OpenehrTemplate, :count)
  end

  it 'rejects non-OPT filenames' do
    bad = Rack::Test::UploadedFile.new(__FILE__, 'text/plain')
    expect { described_class.call(file: bad, root: @root) }
      .to raise_error(described_class::InvalidTemplate, /\.opt/)
  end

  it 'rejects files that do not parse as an OPT' do
    Dir.mktmpdir do |dir|
      fake = File.join(dir, 'broken.opt')
      File.write(fake, '<not-an-opt/>')
      upload = Rack::Test::UploadedFile.new(fake, 'application/xml')

      expect { described_class.call(file: upload, root: @root) }
        .to raise_error(described_class::InvalidTemplate)
    end
  end
end
