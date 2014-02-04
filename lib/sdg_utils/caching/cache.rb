module SDGUtils
  module Caching

    class Cache
      attr_reader :hits, :misses, :name

      def initialize(name="", hash={})
        @name = name
        @cache = {}
        @hits = 0
        @misses = 0
        @accept_nils = !!hash[:accept_nils]
        @on_miss = nil
        @on_hit = nil
        if hash[:fast]
          self.singleton_class.class_eval <<-RUBY, __FILE__, __LINE__+1
            def fetch(key, &block)
              if @cache.has_key?(key)
                @cache[key]
              else
                @cache[key] = block.call()
              end
            end
          RUBY
        elsif hash[:fake]
          self.singleton_class.class_eval <<-RUBY, __FILE__, __LINE__+1
            def fetch(key, &block)
              miss(key, block)
            end
          RUBY
        end
      end

      def clear() @cache.clear end
      def accept_nils?() @accept_nils end
      def reject_nils?() !@accept_nils end

      def fetch(key, fake=false, &block)
        if !fake && ans = @cache[key]
          hit(key, ans)
        else
          miss(key, block)
        end
      end

      def on_miss(&block) @on_miss = wrap_block(block); self end
      def on_hit(&block)  @on_hit = wrap_block(block); self end

      private

      def hit(key, ans)
        @hits += 1
        @on_hit.call(self, key, ans) if @on_hit
        ans
      end

      def miss(key, block)
        @misses += 1
        @on_miss.call(self, key) if @on_miss
        ans = block.call()
        @cache[key] = ans unless ans.nil? && reject_nils?
        ans
      end

      def wrap_block(block)
        case
        when block.arity == 0
          lambda{|*args| block.call}
        when block.arity == -1
          block
        else
          lambda { |*args|
            bargs = (0...block.arity).map {|i| args[i]}
            block.call(*bargs)
          }
        end
      end
    end

  end
end
