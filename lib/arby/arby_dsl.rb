require 'arby/dsl/model_builder'
require 'arby/ast/types'

module Arby

  # ================================================================
  # == Module +Dsl+
  #
  # Included in all user defined (via the +AlloyDsl::Dsl#alloy_model+
  # method) Alloy models.
  # ================================================================
  module Dsl
    extend self

    # Creates a new module and assigns a constant to it (named +name+
    # in the current scope).  Then executes the +&body+ block using
    # +module_eval+.  All Alloy sigs must be created inside an "alloy
    # model" block.  Inside of this module, all undefined constants
    # are automatically converted to symbols.
    #
    # @param name [String, Symbol] --- model name
    # @return [ModelBuilder] --- the builder used to create the module
    def alloy_model(name="", opts={}, &block)
      opts2 = { :return => :builder }
      opts2.merge!(:parent_module => self) if Module === self && self != Arby::Dsl
      opts2.merge!(opts)
      ModelBuilder.new(opts2).model(:alloy, name, &block)
    end

    # Different aliases for the +alloy_model+ method.
    alias_method :alloy_module, :alloy_model
    alias_method :alloy, :alloy_model
  end

end

require 'arby/dsl/ext.rb'
