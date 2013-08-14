require 'generators/openehr'

module Openehr
  module Generators
    class ModelGenerator < ArchetypedBase
      source_root File.expand_path("../templates", __FILE__)
      desc "generate archetype model and migragion file"

      def create_empty_directory
        empty_directory File.join('app/models')
      end

      def generate_rm
        template 'rm.rb', File.join('app/models', 'rm.rb')
      end

      def generate_archetype
        template 'archetype.rb', File.join('app/models', 'archetype.rb')
      end

      def generate_archtype_based_active_model
        template 'activemodel.rb', File.join('app/models', "#{model_name}.rb")
      end

      protected
      def atcodes(cobj)
        case cobj.rm_type_name
        when 'ELEMENT'
          add_atcode_methods cobj
        else
          html = ''
          if cobj.respond_to? :attributes
            html += cobj.attributes.inject('') do |form, attr|
              form += if attr.respond_to? :children
                        attr.children.inject('') {|h, child| h += atcodes child;h}
                      else
                        ''
                      end
              form
            end
            html
          end
          html
        end
      end

      private

      def add_atcode_methods(cobj)        
        val = cobj.attributes.select {|attr| attr.rm_attribute_name == 'value'}[0]
        atval = case val.children[0].rm_type_name
                when 'DvQuantity'
                  'num_value'
                when 'DvText'
                  'text_value'
                when 'DvCodedText'
                  'text_value'
                when 'DvDate'
                  'date_value'
                else
                  'text_value'
                end
        return <<ATFORM
  def #{cobj.node_id}model
    @#{cobj.node_id} ||= confat('#{cobj.node_id}', '#{val.path}')
  end

  def #{cobj.node_id}
    #{cobj.node_id}model.#{atval}
  end

  def #{cobj.node_id}=(#{cobj.node_id})
    #{cobj.node_id}model.#{atval} = #{cobj.node_id}
  end
ATFORM
      end
    end
  end
end

