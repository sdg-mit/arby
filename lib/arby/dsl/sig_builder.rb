require 'arby/ast/sig'
require 'sdg_utils/dsl/class_builder'

module Arby
  module Dsl

    # ============================================================================
    # == Class +SigBuilder+
    #
    # Used to create sig classes.
    # ============================================================================
    class SigBuilder < SDGUtils::DSL::ClassBuilder
      def self.in_sig?()       curr = self.get and curr.in_builder? end
      def self.in_sig_body?()  curr = self.get and curr.in_body? end

      def initialize(options={})
        super({
          :superclass => Arby::Ast::Sig,
          :defer_body_eval => Arby.conf.defer_body_eval
        }.merge!(options))
      end

      def self.sig(*args, &block)
        new.sig(*args, &block)
      end

      # Creates a new class, subclass of either +Arby::Ast::Sig+ or a
      # user supplied super class, and assigns a constant to it (named
      # +name+ in the current scope)
      #
      # @param args [Array] --- valid formats are:
      #
      #    (1) +args.all?{|a| a.respond_to :to_sym}+
      #
      #          for each +a+ in +args+ creates an empty sig with that
      #          name and default parent
      #
      #    (2) [Class, String, Symbol], [Hash, NilClass]
      #
      #          - for class name:   +args[0].to_s+ is used
      #          - for parent sig:   the default is used
      #          - for class params: +args[1] || {}+ is used
      #
      #    (3) [MissingBuilder], [Hash, NilClass]
      #
      #          - for class name:   +args[0].name+ is used
      #          - for parent sig:   +args[0].super || default_supercls+ is used
      #          - for class params: +args[0.args.merge(args[1])+ is used
      #
      # @param block [Proc] --- if the block is given insided the
      #    curly braces, it is interpreted as appended facts;
      #    otherwise (given inside do ... end) it is evaluated using
      #    +class_eval+.
      def sig(*args, &block)
        Arby.meta.add_sig_builder(self)
        ans = build(*args, &block)
        return_result(:array).each do |sig|
          ModelBuilder.in_model_body?           and
            mod = ModelBuilder.get.scope_module and
            mod.respond_to? :meta, true         and
            meta = mod.meta                     and
            meta.respond_to? :add_sig, true     and
            meta.add_sig(sig)
        end
        ans
      end
    end

  end
end
