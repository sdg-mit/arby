require 'arby/dsl/helpers'
require 'arby/dsl/command_helper'
require 'arby/dsl/sig_builder'
require 'arby/dsl/errors'
require 'arby/ast/model'
require 'arby/ast/scope'
require 'arby/ast/expr_builder'
require 'arby/ast/type_consts'
require 'sdg_utils/delegator'
require 'sdg_utils/lambda/sourcerer'

module Arby
  module Dsl

    # ============================================================================
    # == Class +Model+
    #
    # Module to be included in each +alloy_model+.
    # ============================================================================
    module ModelDslApi
      include QuantHelper
      include MultHelper
      include AbstractHelper
      include FunHelper
      include CommandHelper
      include Arby::Ast::TypeConsts
      include Arby::Ast::Expr::ExprConsts
      extend self

      # protected

      # --------------------------------------------------------------
      # Creates a new class, subclass of either Arby::Ast::Sig or a
      # user supplied super class, creates a constant with a given
      # +name+ in the callers namespace and assigns the created class
      # to it.
      #
      # @param args [Array] --- @see +SigBuilder#sig+
      # @return [SigBuilder]
      # --------------------------------------------------------------
      def sig(*args, &block)
        SigBuilder.new({
          :return => :builder
        }).sig(*args, &block)
      end

      def ordered(blder, &block)
        blder.apply_modifier("ordered", nil, &block)
      end

      def iden() Arby::Ast::Expr::ExprConsts::IDEN end
      def univ(rhs=nil)
        case
        when rhs && ModBuilder === rhs && rhs.pending_product?
          Arby::Ast::AType.product(Arby::Ast::TypeConsts::Univ,rhs.rhs_type,rhs.mod_smbl)
        when rhs.nil?
          Arby::Ast::Expr::ExprConsts::UNIV
        else
          raise SyntaxError, "invalid univ arg: #{rhs}:#{rhs.class}"
        end
      end

      def enum(*args, &block)
        case
        when args.size == 1 && SDGUtils::DSL::MissingBuilder === args.first then
          missb = args.first
          base_sig_cls = abstract(sig(missb.name)).return_result(:array).first
          missb.args.each do |mb|
            one(sig(mb < base_sig_cls))
          end
          base_sig_cls.meta.set_enum
        else
          raise Arby::Dsl::SyntaxError, "invalid enum args"
        end
      end

      def open(*mods)
        mods.each do |mod|
          Arby::Ast::TypeChecker.check_arby_module!(mod)
          send :include, mod unless self.include?(mod)
          send :extend, mod
          send :const_set, mod.relative_name, mod
          meta.add_open(mod.meta)
        end
      end

      def exactly(int_scope)
        Arby::Ast::SigScope.new(nil, int_scope, true)
      end

      def __created(scope_module)
        require 'arby/arby.rb'
        mod = Arby.meta.find_model(name) || __create_model(scope_module)
        Arby.meta.add_model(mod)
        __define_meta(mod)
      end

      def __eval_body(&block)
        mod = meta()
        Arby.meta.open_model(mod)
        begin
          body_src = nil # SDGUtils::Lambda::Sourcerer.proc_to_src(block) rescue nil
          if body_src
            Arby::Utils::CodegenRepo.module_eval_code mod.ruby_module, body_src,
                                                       *block.source_location
          else
            mod.ruby_module.module_eval &block
          end
        ensure
          Arby.meta.close_model(mod)
          # delegate all method_missing to its meta
          mod.ruby_module.instance_variable_set "@target", mod
          mod.ruby_module.send :extend, SDGUtils::MDelegator
        end
      end

      def __finish
        meta().send :resolve
      end

      def __create_model(scope_module)
        Arby::Ast::Model.new(scope_module, self)
      end

      def __define_meta(alloy_model)
        define_singleton_method :meta, lambda{alloy_model}
      end

    end

  end
end
