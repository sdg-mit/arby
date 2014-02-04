require 'arby/ast/arg'
require 'sdg_utils/string_utils'

 module Arby
  module Ast

    # ----------------------------------------------------------------------
    # Holds meta information about a field of a sig.
    #
    # @attr parent [Class <= ASig]
    # @attr name [String]
    # @attr type [AType]
    # @attr inv [Field]
    # @attr impl [Field, Proc: Field]
    # @attr synt [TrueClass, FalseClass]
    # @attr belongs_to_parent [TrueClass, FalseClass]
    # @immutable
    # ----------------------------------------------------------------------
    class Field < Arg
      attr_reader   :parent, :inv, :impl, :synth
      attr_accessor :default

      def self.getter_sym(fld) Arg.getter_sym(fld) end
      def self.setter_sym(fld) Arg.setter_sym(fld) end

      # Hash keys:
      #   :parent [ASig]            - parent sig
      #   :name [String]            - name
      #   :type [AType]             - type
      #   :default [object]         - default value
      #   :inv [Field]              - inv field
      #   :synth [Bool]             - whether synthesized of defined by the user
      #   :belongs_to_parent [Bool] - whether its value is owned by field's parent
      #   :transient [Bool]         - whether it is transient (false by default)
      def initialize(hash)
        super(hash)
        @parent            = hash[:parent]
        @default           = hash[:default]
        @synth             = hash[:synth] || false
        @belongs_to_parent = hash[:belongs_to_parent] || hash[:owned] || false
        @transient         = hash[:transient] || false
        @ordering          = hash[:ordering] || false
        set_inv(hash[:inv])
      end

      alias_method :owner, :parent

      def getter_sym()         Field.getter_sym(self) end
      def setter_sym()         Field.setter_sym(self) end

      def ordering?()          !!@ordering end
      def virtual?()           @transient end
      def transient?()         @transient end
      def persistent?()        !@transient end
      def synth?()             @synth end
      def is_inv?()            @synth && !!@inv && !@inv.synth? end
      def set_inv(invfld)      @inv = invfld; invfld.inv=self unless invfld.nil? end
      def set_impl(impl)       @impl = impl end
      def set_synth()          @synth = true end
      def has_impl?()          !!@impl end
      def impl()               Proc === @impl ? @impl.call : @impl end
      def belongs_to_parent?() !!@belongs_to_parent end

      def ~()                  @inv end

      def full_name(relative=false)
        @parent ? "#{relative ? @parent.relative_name : @parent.name}.#{name}" : name
      end

      def full_type()
        @parent ? Arby::Ast::ProductType.new(@parent.to_atype, @type) : @type
      end

      def full_relative_name() full_name(true) end
      def alloy_name()         "#{Arby.conf.alloy_printer.arg_namer[self]}" end
      def full_alloy_name()
        "#{Arby.conf.alloy_printer.sig_namer[parent]}.#{alloy_name}"
      end

      # @param owner [Arby::Ast::ASig]
      # @param value [Object]
      def set(owner, value)
        owner.write_field(self, value)
      end

      def to_s()
        ret = full_name
        ret = "transient " + ret if transient?
        ret = "synth " + ret if synth?
        ret
      end

      def to_alloy
        decl = "#{name.to_s}: #{type.to_alloy}"
        @synth ? "~#{decl}" : decl
      end

      def to_iden
        SDGUtils::StringUtils.to_iden(full_name)
      end

      def to_arby_expr()
        if is_inv?
          e = Expr::UnaryExpr.transpose Expr::FieldExpr.new(self.inv)
          Expr.add_methods_for_type(e, self.inv.full_type.transpose)
          e
        else
          Expr::FieldExpr.new(self)
        end
      end

      protected

      def inv=(fld) @inv = fld end
    end

  end
end
