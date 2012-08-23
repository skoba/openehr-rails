require 'soap/wsdlDriver'

module OpenEHR
  module Rails
    class CKMAccessor
      def self.retrieve(archetype_id)
        ckmws = SOAP::WSDLDriverFactory.new('http://openehr.org/knowledge/services/ArchetypeFinderBean?wsdl').create_rpc_driver
        ckmws.getArchetypeInADL(archetypeId: archetype_id).m_return
      end
    end
  end
end
