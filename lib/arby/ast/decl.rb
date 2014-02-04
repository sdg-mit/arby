require 'arby/ast/types'
require 'arby/ast/utils'

module Arby
  module Ast

    # ----------------------------------------------------------------------
    # Holds meta information about quantifier decls
    #
    # @attr name [String]
    # @attr domain [Expr]
    # @immutable
    # ----------------------------------------------------------------------
    class Decl
      include Checks

      attr_reader :name, :domain

      # Hash keys:
      #   :name [String]    - name
      #   :domain [AType]   - domain
      def initialize(hash)
        @name   = check_iden hash[:name], "arg name"
        @domain = hash[:type]
      end

      alias_method :type, :domain

      def to_s()
        "#{name}: #{domain}"
      end

      def to_iden
        name.gsub(/[^a-zA-Z0-9_]/, "_")
      end
    end

  end
end
