class Archetype < ActiveRecord::Base
  has_many :rms, dependent: :detroy
end
