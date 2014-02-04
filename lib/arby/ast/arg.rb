require 'arby/ast/types'
require 'arby/ast/utils'

module Arby
  module Ast

    # ----------------------------------------------------------------------
    # Holds meta information about args
    #
    # @attr name [String]
    # @attr type [AType]
    # @immutable
    # ----------------------------------------------------------------------
    class Arg
      include Checks

      attr_reader :name, :type, :expr

      class << self
        def getter_sym(fld)
          case fld
          when Arby::Ast::Arg
            fld.name.to_sym
          when String
            fld.to_sym
          when Symbol
            fld
          else
            msg = "`fld' must be in [Field, String, Symbol], but is #{fld.class}"
            raise ArgumentError, msg
          end
        end

        def setter_sym(fld)
          "#{getter_sym(fld)}=".to_sym
        end
      end

      # @param args [Array] --- valid formats are:
      #
      #   (1) [Hash], in which keys are
      #         :name [String]    - name = args.first[:name]
      #         :type [AType]     - type = args.first[:type]
      #
      #   (2) [String, AType], s.t.
      #         name = args[0]
      #         type = args[1]
      def initialize(*args)
        case
        when args.size == 1 && Hash === args.first
          hash = args.first
          @name    = check_iden hash[:name], "arg name"
          @expr    = hash[:expr] || hash[:type]
          @type    = AType.get(hash[:type] || @expr) # nil is ok at this point
        when args.size == 2
          @name = args[0]
          @expr = args[1]
          @type = AType.get(@expr) # nil is ok at this point
        else
          raise ArgumentError, "expected either a hash or a name/type pair; got `#{args}'"
        end
      end

      def expr()  @resolved_expr ||= Expr.resolve_expr(@expr, self, "expression") end
      def type()  @type ||= AType.get(expr) end
      def decl()  @expr || type end
      def _expr() @expr end

      def scalar?()    @type.scalar? end
      def primitive?() scalar? && @type.range.primitive? end

      def getter_sym() Arg.getter_sym(self) end
      def setter_sym() Arg.setter_sym(self) end

      def to_s()
        "#{name}: #{type}"
      end

      def to_alloy
        "#{name.to_s}: #{type.to_alloy}"
      end

      def to_iden
        name.gsub(/[^a-zA-Z0-9_]/, "_")
      end

      private

      def __update_type(type)
        @type = type
        @resolved_expr = nil
        @expr = type
      end
    end

  end
end
