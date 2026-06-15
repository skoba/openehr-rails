# frozen_string_literal: true

module OpenehrRails
  module Rm
    # ENTRY subtypes are archetype roots inside the composition content.
    class EntryNode < Node
      validates :archetype_id, presence: true
    end

    class Section < Node; end

    class Observation < EntryNode; end
    class Evaluation < EntryNode; end
    class Instruction < EntryNode; end
    class Action < EntryNode; end
    class AdminEntry < EntryNode; end

    class Activity < Node; end

    class History < Node; end

    class PointEvent < Node; end

    class IntervalEvent < Node
      validates :width, presence: true
      validates :math_function_code, presence: true
    end

    class ItemTree < Node; end
    class ItemList < Node; end
    class ItemSingle < Node; end
    class ItemTable < Node; end
    class Cluster < Node; end
    class Element < Node; end
  end
end
