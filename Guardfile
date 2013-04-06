guard 'spork' do
  watch('Gemfile')
  watch('Gemfile.lock')
end

guard 'rspec', :cli => '--drb --color' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb') { :rspec }
end
