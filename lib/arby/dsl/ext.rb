#TODO consider moving some of this stuff to sdg_utils/dsl

require 'arby/arby_ast'
require 'arby/arby_dsl'
require 'arby/ast/tuple_set'
require 'arby/ast/types'
require 'arby/ast/scope'
require 'sdg_utils/dsl/ext'
require 'sdg_utils/meta_utils'
require 'sdg_utils/dsl/missing_builder'

module Arby
  module Ext

    module MArrayExt
      def **(rhs) Arby::Ast::TupleSet.wrap(self) ** rhs end
    end

    #--------------------------------------------------------
    # Converts self to +Arby::Ast::UnaryType+ and then delegates
    # the +*+ operation to it.
    #
    # @see Arby::Ast::AType
    # @see Arby::Ast::UnaryType
    # @see Arby::Ast::ProductType
    #--------------------------------------------------------
    module MMissingBuilderExt
      def *(rhs) ::Arby::Ast::AType.get!(self) * rhs end
      def **(rhs) ::Arby::Ast::AType.get!(self) ** rhs end
    end

    #--------------------------------------------------------
    # Converts this class to +Arby::Ast::UnaryType+ and
    # then delegates the +*+ operation to it.
    #
    # @see Arby::Ast::AType
    # @see Arby::Ast::UnaryType
    # @see Arby::Ast::ProductType
    #--------------------------------------------------------
    module MClassExt
      def *(rhs)  to_atype * rhs end
      def **(rhs) (Arby.symbolic_mode?() ? to_expr : to_atype) ** rhs end

      def set_of()   Arby::Dsl::MultHelper.set(self) end
      def is_sig?()  ancestors.member? Arby::Ast::ASig end
      def to_atype() Arby::Ast::AType.get!(self) end
      def to_expr()  Arby::Ast::Expr.resolve_expr(self) end
    end

    module MFixnumExt
      def exactly
        Arby::Ast::SigScope.new(nil, self, true)
      end
    end

    module MObjectExt
      def to_atype() Arby::Ast::AType.get(self) end
    end

    module MRangeExt
      def to_tuple_set
        require 'arby/ast/tuple_set'
        Arby::Ast::TupleSet.wrap(self)
      end

      def self.delegate_to_ts(*syms)
        syms.each do |sym|
          self.send :define_method, sym do |*a, &b|
            to_tuple_set.send sym, *a, &b
          end
        end
      end

      delegate_to_ts :*, :**, :product, :union, :join
    end
  end
end

SDGUtils::DSL::Ext.safe_extend(Arby::Ext, SDGUtils::DSL::MissingBuilder,
                               Class, Fixnum, Object, Range, Array)

class Array
  alias_method :int_times, :*
  alias_method :str_join, :join

  def *(rhs)
    case rhs
    when Array, Hash, Arby::Ast::Tuple, Arby::Ast::TupleSet
      Arby::Ast::TupleSet.wrap(self) * rhs
    else
      send :int_times, rhs
    end
  end

  def arby_join(op)
    Arby::Ast::ExprBuilder.reduce_to_binary op, *self
  end
end

class Symbol
  alias_method :int_select, :[]
  def [](*a)
    if a.size == 1 && Integer === a.first
      send :int_select, a
    else
      SDGUtils::DSL::MissingBuilder.new(self)[*a]
    end
  end
end
