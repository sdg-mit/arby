module Arby
  module Ast

    class Command
      def self.new_check(name, scope, fun) self.new(:check, name, scope, fun) end
      def self.new_run(name, scope, fun)   self.new(:run, name, scope, fun) end

      attr_reader :kind, :name, :scope, :fun

      def initialize(kind, name, scope, fun)
        @kind = kind
        @name = name || ""
        @scope = scope
        @fun = fun
      end

      def run?()   @kind == :run end
      def check?() @kind == :check end
    end

  end
end
