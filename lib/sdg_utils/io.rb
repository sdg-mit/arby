require 'sdg_utils/delegator'

module SDGUtils
  module IO

    class LoggerIO < Delegator
      def initialize(logger, level=:debug)
        super(logger)
        @level = level
      end

      def <<(str)
        str = "nil" if str.nil?
        # @target << str.to_s
        print str
        self
      end
    end

  end
end
