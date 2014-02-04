module SDGUtils
  module Obj

    module Uninstantiable
      def initialize(*args) fail "#{self.class} is not instantiable" end
    end

  end
end
