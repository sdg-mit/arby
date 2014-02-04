require 'arby/dsl/model_api'
require 'sdg_utils/dsl/module_builder'

module Arby
  module Dsl

    # ============================================================================
    # == Class +ModelBuilder+
    #
    # Used for creating alloy modules.
    #
    # NOTE: not thread safe!
    # ============================================================================
    class ModelBuilder < SDGUtils::DSL::ModuleBuilder
      def self.in_model?()      curr = self.get and curr.in_builder? end
      def self.in_model_body?() curr = self.get and curr.in_body? end

      # def self.extend(model, &block)
      #   mb = ModelBuilder.new #:defer_body_eval => false
      #   mb.instance_variable_set "@mod", model.ruby_module
      #   mb.instance_variable_set "@scope_mod", model.scope_module
      #   mb.eval_body_now! model.ruby_module, :module_eval, &block
      # end

      def initialize(options={})
        other_incl = options.delete(:mods_to_include) || []
        opts = {
          :mods_to_include => [ModelDslApi] + other_incl
        }.merge!(options)
        super(opts)
      end

      #--------------------------------------------------------
      # Creates a modules named +name+ and then executes +&block+
      # using +module_eval+.  All Alloy sigs must be created inside an
      # "alloy model" block.  Inside of this module, all undefined
      # constants are automatically converted to symbols.
      # --------------------------------------------------------
      def model(model_sym, name, &block)
        raise RuntimeError, "Model nesting is not allowed" if in_builder?
        @curr_model = model_sym
        build(name, &block)
      end

      def curr_model() @curr_model end

      protected

      def eval_body(mod, *args, &body)
        mod.extend(mod)
        super
      end
    end

  end
end
