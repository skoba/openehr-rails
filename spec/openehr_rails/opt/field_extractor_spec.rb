require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Opt::FieldExtractor do
  describe 'with bmi_calculation.opt' do
    let(:opt_file) do
      File.expand_path('../../../generators/templates/bmi_calculation.opt', __FILE__)
    end
    let(:template) { OpenehrRails::Opt.parse(opt_file) }
    let(:extractor) { described_class.new(template) }

    describe '#entries' do
      subject(:entries) { extractor.entries }

      it 'finds one entry per archetype root under /content' do
        expect(entries.map { |e| e[:archetype_id] }).to eq(
          %w[openEHR-EHR-OBSERVATION.height.v2
             openEHR-EHR-OBSERVATION.body_weight.v2
             openEHR-EHR-OBSERVATION.body_mass_index.v2]
        )
      end

      it 'reports the RM entry type' do
        expect(entries.map { |e| e[:rm_type] }.uniq).to eq(['OBSERVATION'])
      end

      it 'derives entry concepts from the archetype id' do
        expect(entries.map { |e| e[:concept] }).to eq(
          %w[height body_weight body_mass_index]
        )
      end
    end

    describe '#fields' do
      subject(:fields) { extractor.fields }

      it 'names single-element entries after the archetype concept' do
        expect(fields.map { |f| f[:name] }).to include('height', 'body_weight')
      end

      it 'suffixes extra elements of an entry to keep names unique' do
        names = fields.map { |f| f[:name] }
        expect(names).to include('body_mass_index')
        expect(names).to include('body_mass_index_at0013')
      end

      describe 'height field' do
        subject(:height) { fields.find { |f| f[:name] == 'height' } }

        it 'extracts the RM type' do
          expect(height[:rm_type]).to eq('DV_QUANTITY')
        end

        it 'extracts units from the quantity constraint' do
          expect(height[:units]).to eq('cm')
        end

        it 'extracts the magnitude range' do
          expect(height[:magnitude_range]).to eq([0, 1000])
        end

        it 'keeps the terminology label for i18n' do
          expect(height[:label]).to eq('身長')
        end

        it 'builds the full RM path' do
          expect(height[:path]).to eq(
            '/content[openEHR-EHR-OBSERVATION.height.v2]' \
            '/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value'
          )
        end

        it 'records node id and archetype id' do
          expect(height[:node_id]).to eq('at0004')
          expect(height[:archetype_id]).to eq('openEHR-EHR-OBSERVATION.height.v2')
        end

        it 'maps DV_QUANTITY to a float column' do
          expect(height[:column_type]).to eq(:float)
        end
      end

      describe 'comment field (DV_TEXT, non-ASCII label)' do
        subject(:comment) { fields.find { |f| f[:name] == 'body_mass_index_at0013' } }

        it 'maps DV_TEXT to a string column' do
          expect(comment[:rm_type]).to eq('DV_TEXT')
          expect(comment[:column_type]).to eq(:string)
        end

        it 'keeps the original label' do
          expect(comment[:label]).to eq('判定')
        end
      end
    end
  end

  describe 'with an OPT lacking a uid element' do
    let(:opt_file) do
      File.expand_path('../../../templates/bmi_calculation_without_uid.opt', __FILE__)
    end
    let(:template) { OpenehrRails::Opt.parse(opt_file) }
    let(:extractor) { described_class.new(template) }

    it 'parses templates without a uid' do
      expect(template.template_id.value).to eq('bmi_calculation')
      expect(template.uid).to be_nil
    end

    it 'extracts fields' do
      expect(extractor.fields).not_to be_empty
      expect(extractor.fields.map { |f| f[:rm_type] }).to all(be_a(String))
    end
  end
end
