# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require 'tmpdir'

describe OpenehrRails::RuntimeScaffolder do
  let(:opt_path) do
    File.expand_path('../generators/templates/bmi_calculation.opt', __dir__)
  end
  let(:template) do
    OpenehrTemplate.new(
      template_id: 'bmi_calculation',
      name: 'bmi_calculation',
      content: File.read(opt_path),
      template_type: 'operational_template'
    )
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname.new(dir)
      FileUtils.mkdir_p(@root.join('config'))
      File.write(@root.join('config/routes.rb'),
                 "Rails.application.routes.draw do\nend\n")
      example.run
    end
  end

  it 'reports whether a template is already scaffolded' do
    scaffolder = described_class.new(template, root: @root)
    expect(scaffolder.scaffolded?).to be(false)

    scaffolder.call(migrate: false, reload: false)
    expect(scaffolder.scaffolded?).to be(true)
  end

  it 'writes the OPT file and generates the scaffold' do
    result = described_class.new(template, root: @root).call(migrate: false, reload: false)

    expect(result.model_name).to eq('bmi_calculation')
    expect(result.route_path).to eq('bmi_calculations')
    expect(@root.join('app/models/bmi_calculation.rb').read)
      .to include('include OpenehrRails::Storable')
    expect(@root.join('app/controllers/bmi_calculations_controller.rb')).to exist
    expect(@root.join('config/routes.rb').read).to include('resources :bmi_calculations')
    expect(Dir.glob(@root.join('db/migrate/*_create_bmi_calculations.rb'))).not_to be_empty
  end
end
