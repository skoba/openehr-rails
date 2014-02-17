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
        when 'EVENT'
          add_event cobj
        when 'INTERVAL_EVENT'
          add_event cobj
        else
          add_data_component cobj
        end
      end

      def add_data_component(cobj)
        html = ''
        if cobj.respond_to? :attributes
          html += cobj.attributes.inject('') do |form, attr|
            if attr.respond_to? :children
              form += attr.children.inject('') do |h, child|
                child_atcode = atcodes child
                unless child_atcode.nil?
                  h += child_atcode
                end
                h
              end
            end
            form
          end
        end
        html
      end

      def add_event(cobj)
        add_interval_event(cobj) + add_data_component(cobj)
      end

      def add_interval_event(cobj)
        atcode = cobj.node_id
        path = cobj.path+ "/value"
        atval = "#{atcode}model.text_value"
        atform(atcode, path, atval, 'text_value')
      end
      
      def add_atcode_methods(cobj)
        atcode = cobj.node_id
        val = cobj.attributes.select {|attr| attr.rm_attribute_name == 'value'}[0]
        path = val.path
        type = case val.children[0].rm_type_name
               when 'DvQuantity', 'DV_QUANTITY'
                  'num_value'
               when 'DvText', 'DV_TEXT'
                 'text_value'
               when 'DvCodedText', "DV_CODED_TEXT"
                 'text_value'
               when 'DvDate', 'DV_DATE'
                 'date_value'
               when 'DvTime', 'DvTime'
                 'time_value'
               when 'DvDateTime', 'DvDateTime'
                 'datetime_value'
               else
                 'text_value'
               end
        if val.children[0].rm_type_name == 'DV_CODED_TEXT' ||
            val.children[0].rm_type_name == 'DvCodedText'
          atval = "translate(#{atcode}model.#{type})"
        else
          atval = "#{atcode}model.#{type}"
        end
        atform(atcode, path, atval, type)
      end

      def atform(atcode, path, atval, type)
        return <<ATFORM
  def #{atcode}model
    @#{atcode} ||= confat('#{atcode}', '#{path}')
  end

  def #{atcode}
    #{atval}
  end

  def #{atcode}=(#{atcode})
    #{atcode}model.#{type} = #{atcode}
    #{atcode}model.save
  end

ATFORM
      end
    end
  end
end

