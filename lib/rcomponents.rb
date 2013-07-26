module OpenEHR
  module RComponents
    class Base
      attr_reader :node_id, :path, :rm_type_name
      def initialize(args = { })
        self.node_id = args[:node_id]
        self.path = args[:path]
        self.rm_type_name = args[:rm_type_name]
      end

      def node_id=(node_id)
        raise ArgumentError if node_id.nil?
        @node_id = node_id
      end

      def path=(path)
        raise ArgumentError if path.nil?
        @path= path
      end

      def rm_type_name=(rm_type_name)
        raise ArgumentError if rm_type_name.nil?
        @rm_type_name = rm_type_name
      end
    end

    class RElement < Base
    end

    class REntry < Base
      attr_accessor :data

      def initialize(args = {})
        self.data = args[:data]
      end
    end

    class RObservation < REntry
      attr_accessor :state, :protocol

      def initialize(args = {})
        self.state = args[:state]
        self.protocol = args[:protocol]
        super
      end
    end
  end
end
