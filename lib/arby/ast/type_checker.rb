require 'arby/arby_conf'
require 'arby/ast/types'
require 'sdg_utils/errors'

module Arby
  module Ast

    #-----------------------------------------------------
    # == Class +TypeError+
    #
    # Raised in case of various type errors (e.g., trying
    # to extend a sig from the +String+ class).
    #-----------------------------------------------------
    class TypeError < StandardError
      def self.raise_coercion_error(sym, cls=nil)
        msg = "`#{sym}:#{sym.class}' cannot be converted to type"
        msg += " (i.e., #{cls})" if cls
        raise TypeError, msg
      end

      def self.raise_not_subtype(expected, actual)
        raise TypeError, "`#{actual}' is not subtype of `#{expected}'"
      end
    end

    class ResolveError < StandardError
    end


    #-----------------------------------------------------
    # == Class +TypeChecker+
    #-----------------------------------------------------
    module TypeChecker
      extend self

      # Coerces both arguments (+expected+ and +actual+) to +AType+,
      # and then calls +actual <= expected+.  If either type coercion
      # fails returns nil.
      def check_subtype(expected, actual)
        lhs = AType.get(actual) and
          rhs = AType.get(expected) and
          lhs <= rhs
      end

      def check_subtype!(expected, actual)
        check_subtype(expected, actual) or TypeError.raise_not_subtype(expected, actual)
      end

      # @param type - anything that can be converted to +AType+ via +AType.get!+
      # @param tuple [Array]
      def typecheck!(type, tuple)
        atype = AType.get!(type)
        tuple = Array(tuple)
        msg = "tuple #{tuple} doesn't typecheck against #{atype}"
        raise TypeError, "arities differ: #{msg}" unless atype.arity == tuple.size
        raise TypeError, msg unless atype === tuple
      end

      def typecheck(type, tuple) Arby.conf.typecheck and typecheck!(type, tuple) end
      def assert_type(type)      Arby.conf.typecheck and assert_type!(type) end
      def assert_arity(lhs, rhs) lhs.arity == rhs.arity end

      def assert_type!(type)
        raise TypeError, "no type given: #{type}" unless AType === type && type.arity > 0
      end

      def assert_arity!(lhs, rhs)
        raise TypeError, "arity missmatch #{lhs}, #{rhs}" unless assert_arity(lhs, rhs)
      end

      def check_sig_class(cls, supercls=Arby::Ast::ASig)
        Class === cls && cls < supercls
      end

      def check_sig_class!(cls, supercls=Arby::Ast::ASig, msg="")
        unless check_sig_class(cls, supercls)
          raise TypeError, "#{msg}#{cls} is not a #{supercls} class"
        end
      end

      def check_arby_module(mod, model_cls=Arby::Ast::Model)
        Module === mod &&
          mod.respond_to?(:meta, true) &&
          mod.meta.is_a?(model_cls)
      end

      def check_arby_module!(mod, model_cls=Arby::Ast::Model, msg="")
        unless check_arby_module(mod)
          raise TypeError, "#{msg}#{mod} is not a ruby module used as Alloy model"
        end
      end

      def get_arby_model(mod, model_cls=Arby::Ast::Model)
        case mod
        when model_cls then mod
        when Module
          mod.meta if check_arby_module(mod, model_cls)
        else
          nil
        end
      end

      def get_arby_model!(mod, model_cls=Arby::Ast::Model)
        unless get_arby_model(mod, model_cls)
          raise TypeError, "#{msg}#{mod} is not an arby model or corresponding ruby module"
        end
      end
    end

  end
end
