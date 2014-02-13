require 'arby/bridge/solver_helpers'
require 'arby/arby_conf'
require 'arby/ast/types'
require 'arby/resolver'
require 'arby/utils/codegen_repo'
require 'sdg_utils/caching/searchable_attr'

module Arby
  module Ast

    class Model
      include Arby::Bridge::SolverHelpers
      include SDGUtils::Caching::SearchableAttr

      attr_reader :scope_module, :ruby_module, :name, :relative_name

      def initialize(scope_module, ruby_module)
        @scope_module = scope_module
        @ruby_module = ruby_module
        @name = scope_module.name
        @relative_name = @name.split("::").last
        @resolved = false
        @sig_builders = []

        init_searchable_attrs
      end

      attr_searchable :open, :sig
      attr_searchable :fun, :pred, :assertion, :procedure, :fact
      attr_searchable :command, :run

      def clone()
        ans = self.class.allocate
        self.instance_variables.each do |var|
          var_value = self.instance_variable_get(var)
          val = case var_value
                when Array, Hash, Set then var_value.clone
                else var_value
                end
          ans.instance_variable_set(var, val)
        end
        ans
      end

      def all_funs() funs + preds + assertions + facts end
      def checks() commands.select{|c| c.check?} end
      def runs()   commands.select{|c| c.run?} end

      def reachable_sigs(ans=Set.new)
        sigs.each{|s| ans << s}
        opens.each{|m| m.reachable_sigs(ans)}
        ans.to_a
      end

      def find_pi_sig_for_atom(atom)
        reachable_sigs.find{|s|
          s.meta.atom? && atom.is_a?(s.superclass) && s.meta.atom_id == atom.__alloy_atom_id
        }
      end

      alias_method :all_reachable_sigs, :reachable_sigs

      def to_als()
        require 'arby/utils/alloy_printer'
        Arby::Utils::AlloyPrinter.export_to_als(self)
      end

      def extend(&block)
        ts = SDGUtils::Random.salted_timestamp
        m = Arby::Dsl.alloy "ArbyMod__#{ts}", {
          :parent_module => self.ruby_module,
          :preamble => proc{|mod| mod.open self.ruby_module}
        }, &block
        m.return_result(:array).first
      end

      private

      def add_sig_builder(sb)
        @sig_builders << sb
      end

      def resolve
        return if @resolved
        resolve_everything
        init_inv_fields
        eval_sig_bodies
        add_const_accessors
        add_field_getters if Arby.conf.generate_methods_for_global_fields
        add_funs_to_sig_classes
        @resolved = true
      end

      def add_const_accessors
        mod = self.ruby_module
        mod.constants(false).each do |cst|
          mod.module_eval <<-RUBY, __FILE__, __LINE__+1
            def #{cst}()          #{mod.name}.#{cst} end
            def #{cst}=(val)      #{mod.name}.#{cst}=(val) end
            def self.#{cst}()     self.const_get(#{cst.inspect}) end
            def self.#{cst}=(val)
              self.send :remove_const, #{cst.inspect}
              self.const_set(#{cst.inspect}, val)
            end
          RUBY
        end
        # mod.module_eval <<-RUBY, __FILE__, __LINE__+1
        #   def const_missing(cst) binding.pry; sig(cst) || super(cst) end
        # RUBY
      end

      def add_field_getters
        flds = self.sigs.map{|s| s.meta.fields + s.meta.inv_fields}.flatten
        flds.each do |fld|
          # @ruby_module.send :define_method, fld.getter_sym do
          #   fld.parent.get_cls_field(fld)
          # end
          Arby::Utils::CodegenRepo.module_safe_eval_method @ruby_module,
          fld.getter_sym, <<-RUBY, __FILE__, __LINE__+1
            def #{fld.getter_sym}
               #{fld.parent.name}::#{fld.getter_sym}
            end
          RUBY
        end
      end

      def add_funs_to_sig_classes
        my_model = self
        (self.funs + self.preds).each do |fun|
          if fun.args.first
            dom_cls = fun.args.first.type.domain.klass rescue nil
            if TypeChecker.check_sig_class(dom_cls)
              dom_cls.send :define_method, fun.name do |*args|
                if Arby.symbolic_mode?
                  self.apply_call(fun, *args)
                else
                  self.__execute_predicate(my_model, fun, *args)
                end
              end
            end
          end
        end
      end

      def resolve_everything
        resolve_fields
        resolve_types
      end

      # ----------------------------------------------------------------
      # Goes through all the unresolved fields and only checks if the
      # field name matches a name of another field, in which case
      # resolves it to that other field.
      # ----------------------------------------------------------------
      def resolve_fields
        logger = Arby.conf.logger
        sigs.map{|s| s.meta.fields}.flatten.each do |fld|
          fld.type.reject{|ut| ut.resolved?}.each do |utype|
            src = utype.cls.src
            ref_fld = fld.owner.meta.find_field(src, false)
            if ref_fld
              SDGUtils::MetaUtils.morph_into(utype, FldRefType.new(ref_fld))
            end
          end
        end
      end

      # ----------------------------------------------------------------
      # Goes through all the fields and funs, searches for
      # +UnresolvedRefColType+, resolves them and updates the field
      # information.
      # ----------------------------------------------------------------
      def resolve_types
        logger = Arby.conf.logger
        flds = self.sigs.map{|s| s.meta.fields}.flatten
        funs = self.sigs.map{|s| s.meta.funs + s.meta.preds}.flatten + self.all_funs
        types = flds.map(&:type) + funs.map(&:full_type)

        types.each do |type|
          type.each do |utype|
            col_type = utype.respond_to?(:cls, true) && utype.cls
            if col_type.is_a? UnaryType::ColType::UnresolvedRefColType
              logger.debug "[resolve_fields]   trying to resolve #{col_type}..."
              cls = Arby::Resolver.resolve_type(col_type)
              if cls
                logger.debug "[resolve_fields]     resolved to #{cls}"
                utype.update_cls(cls)
              else
                logger.debug "[resolve_fields]     unable to resolve #{col_type}"
              end
            end
          end
        end
      end

      # ----------------------------------------------------------------
      # Creates inverse fields for the user-defined fields.
      # ----------------------------------------------------------------
      def init_inv_fields(force=false)
        logger = Arby.conf.logger
        self.sigs.each do |r|
          r.meta.pfields.each do |f|
            unless f.inv
              logger.debug "[init_inv_fields] checking field #{f}"
              range_cls = f.type.range.cls.klass rescue Object
              if range_cls < Arby::Ast::ASig
                logger.debug "[init_inv_fields]   defining inverse of #{f}"
                invfld = range_cls.send(:_add_inv_for_field, f)
                logger.debug "[init_inv_fields]     #{invfld} defined"
              end
            end
          end
        end
      end

      # ----------------------------------------------------------------
      # Goes throug all the fields, searches for +UnresolvedRefColType+,
      # resolves them and updates the field information.
      # ----------------------------------------------------------------
      def eval_sig_bodies(force=false)
        return unless Arby.conf.defer_body_eval
        @sig_builders.each(&:eval_body_now!)
        @sig_builders = []
      end

    end
  end
end
