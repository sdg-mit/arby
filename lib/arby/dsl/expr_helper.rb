require 'arby/ast/expr'
require 'arby/ast/expr_builder'
require 'arby/ast/op'

module Arby
  module Dsl

    module ExprHelper
      def no(expr)   Arby::Ast::ExprBuilder.apply(Arby::Ast::Ops::NO, expr) end
      def one(expr)  Arby::Ast::ExprBuilder.apply(Arby::Ast::Ops::ONE, expr) end
      def some(expr) Arby::Ast::ExprBuilder.apply(Arby::Ast::Ops::SOME, expr) end
      def lone(expr) Arby::Ast::ExprBuilder.apply(Arby::Ast::Ops::LONE, expr) end

      def union(*e) Arby::Ast::ExprBuilder.reduce_to_binary(Arby::Ast::Ops::PLUS, *e) end
      def conj(*e)  Arby::Ast::ExprBuilder.reduce_to_binary(Arby::Ast::Ops::AND, *e) end
      def disj(*e)  Arby::Ast::ExprBuilder.reduce_to_binary(Arby::Ast::Ops::AND, *e) end
    end

  end
end
