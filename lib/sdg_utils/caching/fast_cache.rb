module SDGUtils
  module Caching

    class FastCache
      attr_reader :hits, :misses, :name

      def initialize(name="", hash={})
        @name = name
        @cache = {}
      end

      def clear() @cache.clear end

      def fetch(key, &block)
        if @cache.has_key?(key)
          @cache[key]
        else
          @cache[key] = block.call()
        end
      end

    end

  end
end
