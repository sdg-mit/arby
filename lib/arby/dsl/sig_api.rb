require 'arby/dsl/fields_helper'
require 'arby/dsl/fun_helper'
require 'arby/ast/arg'
require 'arby/ast/fun'
require 'arby/ast/types'

module Arby
  module Dsl

    # ============================================================================
    # == Class +DslApi+
    #
    # Used to create sig classes.
    # ============================================================================
    module SigDslApi
      protected

      include FieldsHelper
      include FunHelper

      # ~~~~~~~~~~~~~~~~~~~~~~~~ DSL API ~~~~~~~~~~~~~~~~~~~~~~~~ #

      # ---------------------------------------------------------
      # TODO: DOCS
      # ---------------------------------------------------------
      # @param decl [Array]
      def fields(decl)
        # _to_args(decl).each{|a| _field(a.name, a.type)}
        _to_args(decl).each{|a| _field2(a)}
      end

      alias_method :persistent, :fields
      alias_method :refs, :fields

      def owns(decl)
        # _to_args(decl).each{|a| _field(a.name, a.type, :owned => true)}
        _to_args(decl).each{|a| _field2(a, :owned => true)}
      end

      def transient(decl)
        # _to_args(decl).each{|a| _field(a.name, a.type, :transient => true)}
        _to_args(decl).each{|a| _field2(a, :transient => true)}
      end

      # ---------------------------------------------------------
      # TODO: DOCS
      # ---------------------------------------------------------
      def field(*args)
        _traverse_field_args(args, lambda {|name, type, hash={}|
                               _field(name, type, hash)})
      end

      alias_method :ref, :field

      def synth_field(name, type)
        field(name, type, :synth => true)
      end

      def abstract()    _set_abstract; self end
      def placeholder() _set_placeholder; self end

      # ~~~~~~~~~~~~~~~~~~~~~ callbacks for ClassBuilder ~~~~~~~~~~~~~~~~~~~~~ #
      protected

      def __created()
        _define_meta()
        require 'arby/arby.rb'
        Arby.meta.add_sig(self)
      end
      def __params(*args)     fields(*args) end
      def __eval_body(&block)
        if Arby.conf.detect_appended_facts &&
            SDGUtils::Lambda::Sourcerer.is_curly_block(block) #TODO rescue false
          send :fact, &block
        else
          class_eval &block
        end
      end
      def __finish() end

      # ~~~~~~~~~~~~~~~~~~~~~~~~~~~ private stuff ~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
      private

      def _to_args(decl)
        decl = [decl] if Hash === decl
        _decl_to_args(*decl)
      end

      #------------------------------------------------------------------------
      # For a given field (name, type) creates a getter and a setter
      # (instance) method, and adds it to this sig's +meta+ instance.
      #
      # @param name [String]
      # @param type [AType]
      #------------------------------------------------------------------------
      def _field(name, type, hash={})
        type = Arby::Ast::AType.get!(type)
        # opts = hash.merge(type.args)
        fld = meta.add_field(name, type, hash)
        fld_accessors fld
        fld
      end

      def _field2(arg, hash={})
        fld = meta.add_field2(arg, hash)
        fld_accessors fld
        fld
      end


      def _fld_reader_code(fld) "@#{fld.getter_sym}" end
      def _fld_writer_code(fld, val) "@#{fld.getter_sym} = #{val}" end

      #------------------------------------------------------------------------
      # Defines a getter method for a field with the given symbol +sym+
      #------------------------------------------------------------------------
      def fld_accessors(fld)
        cls = Module.new
        fld_sym = fld.getter_sym
        find_fld_src = if fld.is_inv?
                         "meta.inv_field!(#{fld_sym.inspect})"
                       else
                         "meta.field!(#{fld_sym.inspect})"
                       end
        desc = {
          :kind => :fld_accessors,
          :target => self,
          :field => fld_sym
        }
        getter_src = "intercept_read(#{find_fld_src}) { #{_fld_reader_code(fld)} }"
        setter_src = "intercept_write(#{find_fld_src}, value) { #{_fld_writer_code(fld, 'value')} }"
        Arby::Utils::CodegenRepo.eval_code cls, <<-RUBY, __FILE__, __LINE__+1, desc
          def #{fld_sym}()       #{getter_src} end
          def #{fld_sym}=(value) #{setter_src} end
        RUBY
        cls.instance_method(fld_sym).singleton_class.class_eval <<-RUBY
          def source() #{getter_src.inspect} end
        RUBY
        if fld.type && fld.type.isBool?
          cls.send :alias_method, "#{fld_sym}?".to_sym, fld_sym
        end
        self.send :include, cls
      end

      def _set_abstract
        meta.set_abstract
      end

      def _set_placeholder
        _set_abstract
        meta.set_placeholder
      end

      # -----------------------------------------------------------------------
      # This is called not during class definition.
      # -----------------------------------------------------------------------
      def _add_inv_for_field(f)
        inv_fld = meta.add_inv_field_for(f)
        fld_accessors inv_fld
        inv_fld
      end
    end

  end
end
