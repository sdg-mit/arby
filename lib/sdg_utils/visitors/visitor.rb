require 'sdg_utils/config'
require 'sdg_utils/meta_utils'

module SDGUtils
  module Visitors

    class Visitor
      def self.mk_visitor_obj(visitor_obj=nil, target=Object.new, &visitor_blk)
        case visitor_obj
        when NilClass
          if visitor_blk
            target.define_singleton_method :visit do |*args|
              visitor_blk.call(*args)
            end
          else
            target.define_singleton_method :visit, proc{|*a,&b|}
          end
          target
        when Hash
          visitor_obj.each{|key,val| target.define_singleton_method key.to_sym, val}
          target
        else
          visitor_obj
        end
      end

      def initialize(visitor_obj=nil, &visitor_blk)
        res = Visitor.mk_visitor_obj(visitor_obj, self, &visitor_blk)
        unless res == self
          class << self
            include SDGUtils::MDelegator
            @target = res
          end
        end
      end

      def visit(*args, &block)
      end
    end

    class TypeDelegatingVisitor
      Conf = SDGUtils::Config.new(nil, {
        :top_class        => Object,
        :visit_meth_namer => proc{|cls, cls_short_name| "visit_#{cls_short_name}"},
        :default_return   => proc{|*a| nil}
      })

      def initialize(visitor_obj=nil, opts={}, &visitor_blk)
        @visitor = Visitor.mk_visitor_obj(visitor_obj, &visitor_blk)
        @conf    = Conf.extend(opts)
        @stack   = []
      end

      # Assumes that the first argument is the node to be visited.
      # Delegates to more specific "visit" methods based on that
      # node's type.
      def visit(*args, &block)
        return if args.empty?
        node = args.first
        @stack.push node
        begin
          node.singleton_class.ancestors.select{|cls|
            cls <= @conf.top_class
          }.each do |cls|
            kind = cls.relative_name.downcase
            meth = @conf.visit_meth_namer[cls, kind].to_sym
            if @visitor.respond_to?(meth, true)
              meth_arity = @visitor.method(meth).arity
              meth_arity = -meth_arity if meth_arity < 0
              meth_args = [node, @stack[-2]][0...meth_arity]
              return @visitor.send meth, *meth_args
            end
          end
          return @conf.default_return[node]
        ensure
          @stack.pop
        end
      end
    end

    class DescenderVisitor
      Conf = SDGUtils::Config.new(nil, {
        :callback_method => "visit"
      })

      def initialize(callback_obj=nil, opts={}, &callback_blk)
        @cb = Visitor.mk_visitor_obj(callback_obj, &callback_blk)
        @conf = Conf.extend(opts)
      end

      def descend(node)
        subs = @cb.send @conf.callback_method, node
        subs.each do |sub|
          descend(sub)
        end
      end
    end

  end
end
