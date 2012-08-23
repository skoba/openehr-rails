require 'soap/wsdlDriver'

module OpenEHR
  module Rails
    class CKMAccessor
      def self.retrieve(archetype_id)
        ckmws = SOAP::WSDLDriverFactory.new('http://openehr.org/knowledge/services/ArchetypeFinderBean?wsdl').create_rpc_driver
        adl = ckmws.getArchetypeInADL(archetypeId: archetype_id).m_return
        unless adl.empty?
          return adl
        else
          raise Exception
        end
      end
    end
  end
end
