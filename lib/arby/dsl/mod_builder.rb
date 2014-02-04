require 'arby/ast/types'

module Arby
  module Dsl

    # ============================================================================
    # == Class ModBuilder
    #
    # Used to create expressions like +one/MyType+, +set/MyType+, etc.
    #
    # An object of this class is returned to represent modifiers like
    # "one", "set", "seq", etc, so that +self/MyType+ and
    # +self.MyType+ can result in an instance of +Type+
    # ============================================================================
    class ModBuilder
      def /(other)  ModBuilder.mult(@mod_smbl, other) end
      def **(other) @rhs_type = other; self end

      def pending_product?() @mod_smbl && @rhs_type end
      def rhs_type()         @rhs_type end
      def mod_smbl()         @mod_smbl end

      #------------------------------------------------------------------------
      # Creates an Alloy type with a multiplicity modifier assigned
      # +Arby::Ast::ModType+ for a given multiplicity modifier and a given sig.
      #------------------------------------------------------------------------
      def self.mult(mod_smbl, *args, &block)
        type = args.first
        case type
        when ::NilClass
          new(mod_smbl)
        when ::Arby::Dsl::SigBuilder
          type.apply_modifier(mod_smbl, nil, &block)
        when ::Arby::Ast::Expr::MExpr
          ::Arby::Ast::Expr::UnaryExpr.send mod_smbl, type
        else
          if block
            ::Arby::Dsl::QuantHelper.send mod_smbl, *args, &block
          else
            atype = ::Arby::Ast::AType.get!(type)
            atype.apply_multiplicity(mod_smbl)
          end
        end
      end

      private

      def initialize(mod_smbl)
        @mod_smbl = mod_smbl
        @rhs_type = nil
      end
    end

  end
end
