# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'
require_relative '../../../app/controllers/openehr_rails/application_controller'
require_relative '../../../app/controllers/openehr_rails/openehr_api/compositions_controller'

# #121 (plan docs/design/121-122-structural-date-times-plan.md sections 2-4;
# R-20261128-6 answers 1-4): EVENT.time, HISTORY.origin and
# EVENT_CONTEXT.start_time come back as committed, REST returns the context,
# and no read path makes up a date-time or a setting the record does not have.
describe OpenehrRails::Rm::CompositionCommitter do
  let(:committer) { described_class }
  let(:ehr) { OpenehrRails::Rm::Ehr.find_or_create_by!(ehr_id: 'ehr-121') }
  let(:setting) do
    { '_type' => 'DV_CODED_TEXT', 'value' => 'secondary medical care',
      'defining_code' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { 'value' => 'openehr' },
                           'code_string' => '232' } }
  end

  # The BMI height OBSERVATION with the three date-times set.
  def canonical(start: '2026-03-01T09:30:00+09:00', origin: '2026-03-01T09:30:00+09:00',
                time: '2026-03-01T09:30:00+09:00', context: true)
    hash = BmiCalculation.new(height: 170.0).to_rm_composition.deep_stringify_keys
    if context
      hash['context'] = { '_type' => 'EVENT_CONTEXT', 'setting' => setting }
      hash['context']['start_time'] = { '_type' => 'DV_DATE_TIME', 'value' => start } if start
    end
    history = hash['content'][0]['data']
    history['origin'] = { '_type' => 'DV_DATE_TIME', 'value' => origin } if origin
    history['events'][0]['time'] = { '_type' => 'DV_DATE_TIME', 'value' => time } if time
    hash
  end

  def commit(hash, uid: SecureRandom.uuid, **options)
    committer.commit(hash, uid: uid, ehr: ehr, **options)
  end

  def rows(select, from = 'FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o')
    OpenehrRails::Aql::Executor.execute("SELECT #{select} #{from}").rows
  end

  def history_of(hash)
    hash.dig('content', 0, 'data')
  end

  describe 'REST (canonical JSON) returns what was committed' do
    # bug: red before #121 (each came back as a full UTC instant).
    {
      'a date' => '2026-03-01', 'a year-month' => '2026-03', 'a year' => '2026',
      'a time with an offset' => '2026-03-01T09:30:00+09:00', 'a time to the minute' => '2026-03-01T09:30'
    }.each do |label, value|
      it "keeps #{label} (#{value}) in EVENT.time and HISTORY.origin" do
        returned = commit(canonical(start: value, origin: value, time: value)).to_canonical_hash

        expect(history_of(returned)['origin']).to eq('_type' => 'DV_DATE_TIME', 'value' => value)
        expect(history_of(returned).dig('events', 0, 'time')).to eq('_type' => 'DV_DATE_TIME', 'value' => value)
      end

      it "returns the context with #{label} (#{value}) as its start_time, and the setting" do
        returned = commit(canonical(start: value)).to_canonical_hash

        expect(returned['context']).to eq(
          '_type' => 'EVENT_CONTEXT',
          'start_time' => { '_type' => 'DV_DATE_TIME', 'value' => value },
          'setting' => setting
        )
      end
    end

    # enhancement (R-20261128-6, "add"): the keyword takes a recorded string too
    # (anlage passes a referral date to the day).
    it 'keeps a context_start_time keyword given as a string, as written' do
      composition = commit(canonical(context: false), context_start_time: '2026-03-01')

      expect(composition.to_canonical_hash.dig('context', 'start_time', 'value')).to eq('2026-03-01')
      expect(composition.reload.context_start_time).to eq(Time.utc(2026, 3, 1))
    end

    # regression pin for the column; bug for REST (red before #121: no context).
    it 'keeps a context_start_time keyword given as a Time as an instant' do
      composition = commit(canonical(context: false), context_start_time: Time.utc(2025, 1, 2, 3, 4, 5))

      expect(composition.reload.context_start_time).to eq(Time.utc(2025, 1, 2, 3, 4, 5))
      expect(composition.to_canonical_hash.dig('context', 'start_time', 'value')).to eq('2025-01-02T03:04:05Z')
    end
  end

  describe 'FHIR effectiveDateTime of a runtime record' do
    let(:bmi_opt) { File.read(File.expand_path('../../generators/templates/bmi_calculation.opt', __dir__)) }

    around do |example|
      saved_models = OpenehrRails::Fhir::ResourceRegistry.model_names.dup
      OpenehrRails::Fhir::ResourceRegistry.reset!
      OpenehrRails::Fhir.template_source = -> { [{ template_id: 'bmi_calculation', opt: bmi_opt }] }
      example.run
    ensure
      OpenehrRails::Fhir.template_source = nil
      OpenehrRails::Fhir::ResourceRegistry.reset!
      saved_models.each { |name| OpenehrRails::Fhir::ResourceRegistry.register_model(name) }
    end

    def effective(start)
      commit(canonical(start: start))
      OpenehrRails::Fhir::ResourceQuery.new(resource_type: 'Observation',
                                            archetype_id: 'openEHR-EHR-OBSERVATION.height.v2', subject: nil)
                                       .search.sole[:effectiveDateTime]
    end

    # bug: red before #121 (a full UTC instant).
    %w[2026-03-01 2026-03].each do |start|
      it "serves a recorded start time of #{start} as written (FHIR dateTime rule, #110)" do
        expect(effective(start)).to eq(start)
      end
    end

    # bug: red before #121 (the offset was turned into UTC).
    it 'keeps a recorded offset' do
      expect(effective('2026-03-01T09:30:00+09:00')).to eq('2026-03-01T09:30:00+09:00')
    end
  end

  describe 'ordering and AQL comparison' do
    # regression pin (#109): the instant columns hold the earliest instant, UTC when no offset.
    it 'keeps the instant columns for comparison' do
      composition = commit(canonical(start: '2026-03', origin: '2026-03-01', time: '2026-03-01T09:30:00+09:00'))
      history = OpenehrRails::Rm::Node.find_by(composition_id: composition.id, rm_type: 'HISTORY')
      event = OpenehrRails::Rm::Node.find_by(composition_id: composition.id, rm_type: 'POINT_EVENT')

      expect(composition.reload.context_start_time).to eq(Time.utc(2026, 3, 1))
      expect(history.history_origin).to eq(Time.utc(2026, 3, 1))
      expect(event.event_time).to eq(Time.utc(2026, 3, 1, 0, 30))
    end

    # regression pin (#106, #92 waiting): AQL SELECT returns the normalized instant.
    it 'answers AQL with the normalized instant' do
      commit(canonical(time: '2026-03-01T09:30:00+09:00'))

      expect(rows('o/data/events/time/value')).to eq([['2026-03-01T00:30:00Z']])
    end
  end

  describe 'a commit missing a mandatory date-time or setting is refused' do
    # bug: red before #121 (committed; reads filled in the clock or 'other').
    {
      'EVENT.time' => [{ time: nil }, %r{/events\[at0002\]/time}],
      'HISTORY.origin' => [{ origin: nil }, %r{/data\[at0001\]/origin}],
      'EVENT_CONTEXT.start_time' => [{ start: nil }, %r{/context/start_time}]
    }.each do |label, (options, path)|
      it "refuses a composition without #{label}, naming the path" do
        expect { commit(canonical(**options)) }
          .to raise_error(OpenehrRails::Rm::MissingRequiredAttributes, path)
        expect(OpenehrRails::Rm::Composition.count).to eq(0)
      end
    end

    it 'refuses a context without a setting' do
      hash = canonical
      hash['context'].delete('setting')

      expect { commit(hash) }.to raise_error(OpenehrRails::Rm::MissingRequiredAttributes, %r{/context/setting})
    end

    # regression pin: a composition with no context at all is allowed (COMPOSITION.context is optional).
    it 'accepts a composition with no context' do
      expect { commit(canonical(context: false)) }.not_to raise_error
    end

    # enhancement: /v1 answers 422 with the message.
    it 'is answered with 422 by the /v1 COMPOSITION endpoint' do
      handlers = OpenehrRails::OpenehrApi::CompositionsController.rescue_handlers.to_h

      expect(handlers['OpenehrRails::Rm::MissingRequiredAttributes']).to eq(:render_invalid)
    end
  end

  describe 'a scaffold record (Storable)' do
    let(:record) { BmiCalculation.create!(height: 170.0, composed_at: Time.utc(2026, 3, 1, 0, 30)) }

    # bug: red before #121 (no EVENT.time; AQL returned the clock at query time).
    it 'writes its save time into HISTORY.origin and EVENT.time' do
      history = history_of(record.rm_composition)

      expect(history['origin']).to eq('_type' => 'DV_DATE_TIME', 'value' => '2026-03-01T00:30:00Z')
      expect(history.dig('events', 0, 'time')).to eq('_type' => 'DV_DATE_TIME', 'value' => '2026-03-01T00:30:00Z')
    end

    # bug: red before #121 (AQL returned the clock at query time).
    it 'answers AQL with the save time, not the clock' do
      record

      expect(rows('o/data/events/time/value')).to eq([['2026-03-01T00:30:00Z']])
    end

    # bug: red before #121 (setting other/other, not an openehr code).
    it 'gets the configured setting, 238 other care by default' do
      setting = record.rm_graph.to_rm.context.setting

      expect([setting.defining_code.code_string, setting.value]).to eq(['238', 'other care'])
    end

    # enhancement (R-20261128-6 answer 4): an event record gets its context.
    it 'returns the context through REST' do
      expect(record.rm_graph.to_canonical_hash['context']).to include(
        'start_time' => { '_type' => 'DV_DATE_TIME', 'value' => '2026-03-01T00:30:00Z' },
        'setting' => include('defining_code' => include('code_string' => '238'))
      )
    end

    # enhancement (R-20261128-6 answer 4): a persistent record gets no added context.
    it 'adds no context when the configured category is persistent' do
      saved = OpenehrRails.default_category
      OpenehrRails.default_category = %w[431 persistent]

      expect(record.rm_graph.to_canonical_hash).not_to have_key('context')
    ensure
      OpenehrRails.default_category = saved
    end
  end

  describe 'OpenehrRails.default_setting' do
    # enhancement (R-20261128-6 answer 3): a code outside the openehr setting group fails at once.
    it 'refuses a code that is not an openehr setting' do
      expect { OpenehrRails.default_setting = %w[999 nowhere] }.to raise_error(ArgumentError, /999/)
      expect { OpenehrRails.default_setting = %w[other other] }.to raise_error(ArgumentError, /other/)
    end

    it 'accepts an openehr setting code' do
      saved = OpenehrRails.default_setting
      OpenehrRails.default_setting = ['232', 'secondary medical care']

      expect(OpenehrRails.default_setting).to eq(['232', 'secondary medical care'])
    ensure
      OpenehrRails.default_setting = saved
    end
  end

  # R-20261128-6 answer 1: both RM tables have had `extra` since 0.3.0; a
  # database without it still commits and reads (column list stubbed).
  describe 'a database whose RM tables have no extra column' do
    before do
      [OpenehrRails::Rm::Composition, OpenehrRails::Rm::Node].each do |model|
        allow(model).to(receive(:column_names).and_wrap_original { |original| original.call - ['extra'] })
      end
    end

    # regression pin: nothing is written to extra, and reads fall back to the instant.
    it 'commits, and returns the instants' do
      returned = commit(canonical(start: '2026-03', origin: '2026-03', time: '2026-03')).to_canonical_hash

      expect(history_of(returned).dig('events', 0, 'time', 'value')).to eq('2026-03-01T00:00:00Z')
      expect(returned.dig('context', 'start_time', 'value')).to eq('2026-03-01T00:00:00Z')
    end
  end

  describe 'rows stored before #121' do
    # Simulates a row saved without the recorded strings or EVENT.time; writing
    # the columns directly is the point, so validations are skipped on purpose.
    # rubocop:disable-next Rails/SkipsModelValidations
    def strip_to_old_row(composition, event_time: nil)
      composition.update_columns(extra: nil)
      OpenehrRails::Rm::Node.where(composition_id: composition.id).find_each do |node|
        node.update_columns(extra: nil, event_time: event_time, history_origin: nil) if node.rm_type.end_with?('EVENT')
        node.update_columns(extra: nil, history_origin: nil) if node.rm_type == 'HISTORY'
      end
    end

    # regression pin: what is left of an old row comes back as its instant.
    it 'returns the instant when no recorded string is kept' do
      composition = commit(canonical(time: '2026-03-01T09:30:00+09:00'))
      strip_to_old_row(composition, event_time: Time.utc(2026, 3, 1, 0, 30))

      expect(history_of(composition.to_canonical_hash).dig('events', 0, 'time', 'value')).to eq('2026-03-01T00:30:00Z')
    end

    # bug: red before #121 (Time.current).
    it 'falls back to the context start time for a missing EVENT.time, never the clock' do
      composition = commit(canonical(start: '2026-03-01T09:30:00+09:00'))
      strip_to_old_row(composition)

      expect(rows('o/data/events/time/value')).to eq([['2026-03-01T00:30:00Z']])
    end

    # bug: red before #121 (Time.current).
    it 'leaves out of AQL a row with neither an EVENT.time nor a context' do
      composition = commit(canonical(context: false))
      strip_to_old_row(composition)

      expect(rows('o/data/events/time/value')).to eq([])
    end

    # regression pin: a logical delete re-commits the stored head, old rows included.
    it 'still deletes an old row that has no EVENT.time' do
      composition = commit(canonical(context: false))
      strip_to_old_row(composition)

      expect { committer.delete(uid: composition.uid) }.not_to raise_error
    end
  end
end
