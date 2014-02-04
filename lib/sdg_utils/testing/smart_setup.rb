module SDGUtils
  module Testing

    module SmartSetup
      @@setup_done = {}

      def setup
        unless @@setup_done[self.class]
          setup_class
          @@setup_done[self.class] = true
        end
        setup_test
      end

      def setup_class() end
      def setup_test() end
    end

  end
end
