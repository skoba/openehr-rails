describe FormGenerator do
  before(:each) do
    prepare_destination
    run_generator [form]
  end

  describe 'relement' do
    context 'dv_text' do
      suject {file 'app/views/examples/_form.html.erb'}

      it { is_expected.to contain 'f.text'}
    end
  end
end
