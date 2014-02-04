require 'arby/arby_event_constants.rb'
require 'arby/ast/arg'
require 'arby/ast/expr'
require 'arby/ast/field'
require 'arby/ast/fun'
require 'arby/ast/tuple_set'
require 'arby/ast/sig_meta'
require 'arby/relations/relation'
require 'arby/utils/codegen_repo'
require 'sdg_utils/dsl/missing_builder'
require 'sdg_utils/meta_utils'
require 'sdg_utils/random'

require 'arby/dsl/helpers'
require 'arby/dsl/sig_api'

module Arby
  module Ast

    #=========================================================================
    # == Module ASig::Static
    #=========================================================================
    module ASig

      def self.all_reachable_atoms(atoms, ans=Set.new)
        atoms.each do |a|
          if ASig === a && !ans.member?(a)
            ans << a
            a.class.meta.fields(false).each do |fld|
              fld_val = a.read_field(fld)
              fld_val_atoms = fld_val.tuples.map(&:atoms).flatten
              all_reachable_atoms(fld_val_atoms, ans)
            end
          end
        end
        ans.to_a
      end

      module Static
        def inherited(subclass)
          super
          fail "The +meta+ method hasn't been defined for class #{self}" unless meta
          meta.add_subsig(subclass)
        end

        def new(*a, &b)
          sig_inst = super
          meta().register_atom(sig_inst)
          if Arby.symbolic_mode?
            sig_inst.make_me_sym_expr
          end
          sig_inst
        end

        def allocate
          obj = super
          meta().register_atom(obj)
          obj
        end

        def to_atype()   UnaryType.get!(self) end
        def to_expr()    Expr::SigExpr.new(self) end
        def e()          to_expr() end
        def f(fname)     meta().field(fname) end
        alias_method     :to_arby_expr, :to_expr
        def alloy_name() Arby.conf.alloy_printer.sig_namer[self] end
        alias_method     :__type, :to_atype

        def add_method_for_field(fld)
          unless respond_to?(fld.name.to_sym)
            define_singleton_method fld.name do
              get_cls_field(fld)
              # self.to_expr.join(fld.to_arby_expr)
            end
            # class_eval <<-RUBY, __FILE__, __LINE__+1
            #   def self.#{fld.name}() get_cls_field(#{fld.name.to_s.inspect}) end
            # RUBY
          end
          if oldest_ancestor
            superclass.add_method_for_field(fld)
          end
        end

        def get_cls_field(fld)
          if Arby.symbolic_mode?
            fld.to_arby_expr
            # to_arby_expr.send fld.name.to_sym
          else
            fld
          end
        end

        def |(*args)
          to_atype.send :|, *args
        end

        def method_missing(sym, *args, &block)
          to_arby_expr().send sym, *args, &block
          # # TODO: remove these functinos as well, and instead generate
          # #       methods for alloy funs
          # if block.nil? && fun=meta.any_fun(sym)
          #   # use the instance method bound to self.to_arby_expr
          #   to_arby_expr().apply_call(fun, *args)
          # else
          #   return super
          # end
        end

        def abstract?() meta.abstract? end
        def ordered?()  meta.ordered? end

        def set_abstract() meta.set_abstract end
        def set_one()      meta.set_one end
        def set_lone()     meta.set_lone end
        def set_atom(*a)   meta.set_atom(*a) end
        def set_ordered()
          meta.set_ordered
          #TODO: move elsewhere
          meta.add_field(:next, self, :transient => true)
          meta.add_field(:nexts, self, :transient => true)
          n = Field.new(:name     => "next",
                        :parent   => self,
                        :type     => self ** self,
                        :ordering => true)
          f = Field.new(:name     => "first",
                        :parent   => self,
                        :type     => self,
                        :ordering => true)
          l = Field.new(:name     => "last",
                        :parent   => self,
                        :type     => self,
                        :ordering => true)
          define_singleton_method :next do get_cls_field(n) end
          define_singleton_method :first do get_cls_field(f) end
          define_singleton_method :last do get_cls_field(l) end
        end

        # @see +SigMeta#placeholder?+
        # @return [TrueClass, FalseClass]
        def placeholder?() meta.placeholder? end

        # @see +SigMeta#ignore_abstract+
        # @return [Class, NilClass]
        def oldest_ancestor(ignore_abstract=false)
          meta.oldest_ancestor(ignore_abstract)
        end

        # Returns highest non-placeholder ancestor of +self+ in the
        # inheritance hierarchy or self.
        def alloy_root
          meta.oldest_ancestor(false) || self
        end

        def all_supersigs()  meta.all_supersigs end
        def all_subsigs()  meta.all_subsigs end

        #------------------------------------------------------------------------
        # Returns a string representation of this +Sig+ conforming to
        # the Alloy syntax
        #------------------------------------------------------------------------
        def to_alloy
          Arby::Utils::AlloyPrinter.export_to_als(self)
        end

        #------------------------------------------------------------------------
        # Defines the +meta+ method which returns some meta info
        # about this sig's fields
        #------------------------------------------------------------------------
        def _define_meta()
          meta = Arby::Ast::SigMeta.new(self)
          define_singleton_method(:meta, lambda {meta})
          meta
        end

        #------------------------------------------------------------------------
        # Checks whether the specified hash contains exactly one
        # entry, whose key is a valid identifier, and whose value is a
        # subtype of the specified type (`expected_type')
        # ------------------------------------------------------------------------
        def _check_single_fld_hash(hash, expected_type=Object)
          msg1 = "Hash expected, got #{hash.class} instead"
          msg2 = "Expected exactly one entry, got #{hash.length}"
          raise ArgumentError, msg1 unless hash.kind_of? Hash
          raise ArgumentError, msg2 unless hash.length == 1

          varname, type = hash.first
          msg = "`#{varname}' is not a proper identifier"
          raise ArgumentError, msg unless SDGUtils::MetaUtils.check_identifier(varname)
          Arby::Ast::TypeChecker.check_subtype(expected_type, type)
        end

        def __parent() nil end
      end
    end

    #------------------------------------------
    # == Module ASig
    #------------------------------------------
    module ASig
      include SDGUtils::ShadowMethods

      attr_accessor :__label, :__alloy_atom_id
      attr_reader   :__atom_id

      def self.included(base)
        base.extend(Arby::Dsl::StaticHelpers)
        base.extend(Static)
        base.extend Arby::Dsl::SigDslApi
        base.send :include, Arby::Dsl::InstanceHelpers
        base.send :__created
      end

      def meta()     self.class.meta end
      def arity()    1 end
      def to_s()     @__label end
      def to_atype() UnaryType.get!(self.class) end
      def to_expr()  Expr::AtomExpr.new(self) end
      def to_ts()    TupleSet.wrap(self, to_atype) end

      alias_method :to_arby_expr, :to_expr

      def initialize(*args)
        super()

        cls = self.class
        id_cnt = cls.instance_variable_get("@sig_id_cnt") || 0
        @__atom_id = id_cnt
        @__label = "#{cls.relative_name}$#{id_cnt}"
        cls.instance_variable_set("@sig_id_cnt", id_cnt + 1)

        init_fld_values(*args)
        init_default_transient_values
        meta().register_atom(self)
      end

      def registered?()    @registered end
      def set_registered() @registered = true end

      def read_field(fld)       send Arby::Ast::Field.getter_sym(fld) end
      def write_field(fld, val) send Arby::Ast::Field.setter_sym(fld), val end

      def make_me_sym_expr(name="self")
        p = __parent()
        if ASig === p
          p.make_me_sym_expr("#{name}_parent")
        end
        Arby::Ast::Expr.as_atom(self, name)
        self
      end

      def __parent() nil end

      def __execute_predicate(model, fun, *args)
        atoms = [self] + args
        bnd = Instance.from_atoms(self, *args).to_bounds
        sol = model.solve fun.name, bnd
        if sol.satisfiable?
          inst = sol.arby_instance
          ans = fun.args[atoms.size..-1].map{ |arg|
            inst["$#{fun.name}_#{arg.name}"]
          }
          if    ans.size == 0 then nil
          elsif ans.size == 1 then ans.first
                              else ans
          end
        else
          nil
        end
      end

      def *(other)  (Arby.symbolic_mode?() ? to_expr : to_ts) * other end
      def **(other) (Arby.symbolic_mode?() ? to_expr : to_ts) ** other end

      protected

      def this() self end

      include Arby::EventConstants

      def intercept_read(fld)
        _fld_pre_read(fld)
        value = yield
        value = TupleSet.wrap(value, fld.type) if Arby.conf.wrap_field_values
        _fld_post_read(fld, value)
      end

      def intercept_write(fld, value)
        value = TupleSet.unwrap(value) if Arby.conf.wrap_field_values
        _fld_pre_write(fld, value)
        yield
        _fld_post_write(fld, value)
      end

      def _fld_pre_read(fld)
        # Arby.boss.fire E_FIELD_TRY_READ, object: self, field: fld
        true
      end

      def _fld_pre_write(fld, val)
        # Arby.boss.fire E_FIELD_TRY_WRITE, object: self, field: fld, value: val
        true
      end

      def _fld_post_read(fld, val)
        Arby.boss.fire E_FIELD_READ, object: self, field: fld, :return => val
        val
      end

      def _fld_post_write(fld, val)
        Arby.boss.fire E_FIELD_WRITTEN, object: self, field: fld, value: val
        val
      end

      def init_default_transient_values
        meta.tfields.each do |tf|
          if tf.type.unary? && tf.type.range.cls.primitive?
            val = tf.type.range.cls.default_value
            self.write_field(tf, val)
          end
        end
      end

      def init_fld_values(*args)
        case
        when args.size == 1 && Hash === args.first
          args.first.each do |name, value|
            self.write_field(name, value)
          end
        end
      end
    end

    #================================================================
    # == Class Sig
    #================================================================
    class Sig
      include ASig
      meta.set_placeholder
    end

    def self.create_sig(name, super_cls=Arby::Ast::Sig)
      sb = Arby::Dsl::SigBuilder.new({
             :superclass => super_cls,
             :return     => :as_is
      }).sig(name)
    end

  end
end
