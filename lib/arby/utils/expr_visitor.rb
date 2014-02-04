require 'arby/ast/expr'
require 'sdg_utils/visitors/visitor'

module Arby
  module Utils

    class ExprDelegatingVisitor < SDGUtils::Visitors::TypeDelegatingVisitor
      def initialize(visitor_obj=nil, opts={}, &visitor_blk)
        super(visitor_obj,
              {top_class: Arby::Ast::Expr::MExpr}.merge(opts),
              &visitor_blk)
      end

    end

    # ============================================================================
    # == Class +ExprDescender+
    #
    # Descends expressions
    # ============================================================================
    class ExprDescender
      Conf = SDGUtils::Config.new(nil, {
        :callback_method => "visit"
      })

      def initialize(visitor_obj=nil, opts={}, &visitor_blk)
        @visitor = SDGUtils::Visitors::Visitor.mk_visitor_obj(visitor_obj, &visitor_blk)
        @conf = Conf.extend(opts)
        @evis = ExprDelegatingVisitor.new(self)
      end

      def visit(expr)
        @evis.visit(expr)
      end

      def visit_mexpr(e)
        notify(e)
        []
      end

      def visit_naryexpr(e)
        notify(e)
        e.children
      end

      def visit_parenexpr(e)
        notify(e)
        [e.sub]
      end

      def visit_callexpr(e)
        notify(e)
        [e.target, e.args]
      end

      def visit_iteexpr(e)
        notify(e)
        [e.cond, e.then_expr, e.else_expr]
      end

      def visit_quantexpr(e)
        notify(e)
        [body]
      end

      protected

      def notify(e)
        @visitor.send @conf.callback_method, e
      end
    end

    # ============================================================================
    # == Class +ExprRebuilder+
    #
    # Rebuilds expressions
    # ============================================================================
    class ExprRebuilder
      Conf = SDGUtils::Config.new(nil, {
        :callback_method => "visit"
      })

      def initialize(visitor_obj=nil, opts={}, &visitor_blk)
        @visitor = SDGUtils::Visitors::Visitor.mk_visitor_obj(visitor_obj, &visitor_blk)
        @conf = Conf.extend(opts)
        @evis = ExprDelegatingVisitor.new(self)
      end

      def rebuild(e)
        @evis.visit(e)
      end

      def visit_mexpr(e)
        notify(e) { e }
      end

      def visit_unaryexpr(e)
        notify(e) do
          sub = rebuild(e.sub)
          unless_obj_eq(e, sub, e.sub) do
            Arby::Ast::Expr::UnaryExpr.new e.op, sub
          end
        end
      end

      def visit_binaryexpr(e)
        notify(e) do
          lhs = rebuild(e.lhs)
          rhs = rebuild(e.rhs)
          unless_obj_eq(e, lhs, rhs, e.lhs, e.rhs) do
            Arby::Ast::Expr::BinaryExpr.new e.op, lhs, rhs
          end
        end
      end

      def visit_naryexpr(e)
        notify(e) do
          ch = e.children.map(&method(:rebuild))
          unless_obj_eq(e, *ch, *e.children) do
            Arby::Ast::Expr::NaryExpr.new e.op, *ch
          end
        end
      end

      def visit_parenexpr(e)
        notify(e) do
          sub = rebuild(e.sub)
          unless_obj_eq(e, sub, e.sub) do
            Arby::Ast::Expr::ParenExpr.new e.op, sub
          end
        end
      end

      def visit_callexpr(e)
        notify(e) do
          target = rebuild(e.target)
          args = e.args.map(&method(:rebuild))
          unless_obj_eq(e, target, *args, e.target, *e.args) do
            Arby::Ast::Expr::CallExpr.new target, e.fun, *args
          end
        end
      end

      def visit_iteexpr(e)
        notify(e) do
          e_args = [e.cond, e.then_expr, e.else_expr]
          args = e_args.map(&method(:rebuild))
          unless_obj_eq(e, *args, *e_args) do
            Arby::Ast::Expr::ITEExpr.new *args
          end
        end
      end

      def visit_quantexpr(e)
        notify(e) do
          body = rebuild(e.body)
          unless_obj_eq(e, body, e.body) do
            if e.all?
              Arby::Ast::Expr::QuantExpr.all(e.decl, body)
            elsif e.exist?
              Arby::Ast::Expr::QuantExpr.exist(e.decl, body)
            end
          end
        end
      end

      protected

      def notify(e, &cont)
        ans = @visitor.send @conf.callback_method, e
        if ans
          ans
        else
          cont.call
        end
      end

      def unless_obj_eq(e, *objs, &blk)
        # if objs.each_slice(2).all?{|obj_pair| obj_eq(*obj_pair)}
        if (0...objs.size/2).all?{|i| obj_eq objs[i], objs[2*i]}
          e
        else
          blk.call
        end
      end

      def obj_eq(o1, o2) o1.__id__ == o2.__id__ end
    end


  end
end
