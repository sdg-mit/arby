require 'arby/ast/types'

module Arby
  module Ast

    module SigConsts
      class UnivCls
        def self.relative_name() "univ" end
      end
    end

    module TypeConsts
      extend self

      # Univ  = UnaryType.new(SigConsts::UnivCls)
      Univ  = UnivType.new
      Univ1 = Univ
      None  = NoType.new
      Int   = UnaryType.new(Integer)
      Bool  = UnaryType.new(:Bool)
      Seq   = ProductType.new(Int, Univ)

      def Int(a=nil)  a ? Expr.resolve_expr(a) : TypeConsts::Int end
      def Bool(b=nil) b ? Expr.resolve_expr(b) : TypeConsts::Bool end
      def Univ() TypeConsts::Univ end
      def None() TypeConsts::None end

      def self.get(sym)
        case sym.to_s
        when "Int", "Integer"  then Int
        when "seq/Int"         then Int
        when "univ"            then Univ
        when "none"            then None
        when "Bool", "Boolean" then Bool
        else
          nil
        end
      end

      def self.get!(sym) self.get(sym) or TypeError.raise_type_coercion_error(sym) end
    end

  end
end
