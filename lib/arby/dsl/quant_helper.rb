require 'arby/ast/expr'
require 'arby/ast/decl'
require 'arby/dsl/expr_helper'
require 'arby/dsl/fields_helper'
require 'sdg_utils/dsl/missing_builder'

module Arby
  module Dsl

    module QuantHelper
      extend self
      include ExprHelper

      def all(*decls, &body)    _quant(:all, decls, body)   end
      def exist(*decls, &body)  _quant(:exist, decls, body) end
      def let(*decls, &body)    _quant(:let, decls, body)   end
      def select(*decls, &body) _quant(:setcph, hash, body) end

      def no(*expr, &body)   (body) ? _quant(:no, expr, body)    : _mult(:no, *expr)   end
      def one(*expr, &body)  (body) ? _quant(:one, expr, body)   : _mult(:one, *expr)  end
      def lone(*expr, &body) (body) ? _quant(:lone, expr, body)  : _mult(:lone, *expr) end
      def some(*expr, &body) (body) ? _quant(:exist, expr, body) : _mult(:some, *expr) end

      private

      def _quant(kind, decls, body)
        args = FieldsHelper.send :_decl_to_args, *decls
        Arby::Ast::Expr::QuantExpr.send kind, args, body
      end

      def _mult(meth, *args)
        ExprHelper.instance_method(meth).bind(self).call(*args)
      end
    end

  end
end
