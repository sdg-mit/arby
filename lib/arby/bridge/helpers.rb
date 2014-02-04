module Arby
  module Bridge

    # ------------------------------------------------------------------
    # Various helper methods for dealing with Rjb::Proxy objects.
    # ------------------------------------------------------------------
    module Helpers
      extend self

      # @param a4arr [Rjb::Proxy ~> Array]
      # @return [Array]
      def java_to_ruby_array(a4arr)
        ans = []
        a4it = a4arr.iterator
        while a4it.hasNext
          ans << a4it.next
        end
        ans
      end

      # @param a4arr [Rjb::Proxy ~> Array]
      # @return [Array]
      def jmap(a4arr)
        java_to_ruby_array(a4arr).map{|*a| yield(*a)}
      end

      def jmap_iter(a4iterable)
        a4iterator = a4iterable.iterator
        ans = []
        while a4iterator.hasNext
          t = a4iterator.next
          ans << yield(t)
        end
        ans
      end
    end
  end
end
