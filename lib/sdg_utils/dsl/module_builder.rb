require 'sdg_utils/meta_utils'
require 'sdg_utils/dsl/base_builder'

module SDGUtils
  module DSL

    #=========================================================================
    # == Class ModuleBuilder
    #
    #=========================================================================
    class ModuleBuilder < BaseBuilder

      # constructor
      def initialize(options={})
        super({
          :parent_module         => lambda{SDGUtils::MetaUtils.caller_module},
          :include_module_mthd   => :__include,
          :preamble              => proc{},
          :mods_to_include       => []
        }.merge!(options))
        opts_to_flat_array :mods_to_include
      end

      #--------------------------------------------------------
      # Returns the current module, i.e., the module created in the
      # last execution of +build+.  This is the module in whose scope
      # the body is evaluated.  Only in the case when no name was
      # provided in the declaration of this module, all assignments
      # will be fowarded to the parent module, which we call the
      # "scope" module.
      # --------------------------------------------------------
      def current_module
        @mod
      end

      #--------------------------------------------------------
      # Returns the current scope module, i.e., the module in which
      # the created sigs get assigned.  If a non-empty name was
      # provided in the module definition, that the scope module is
      # the same as the current module.
      # --------------------------------------------------------
      def scope_module
        @scope_mod
      end

      protected

      #--------------------------------------------------------
      # Creates a module named +name+ and then executes +body+ using
      # +module_eval+.  Inside of this module, all undefined constants
      # are automatically converted to symbols.
      # --------------------------------------------------------
      def do_build(name, &body)
        name = nil if name && name.empty?
        @mod = create_or_get_module(name)
        @scope_mod = name ? @mod : @conf.parent_module
        safe_send @mod, @conf.created_mthd, @scope_mod
        @conf.preamble[@mod] if @conf.preamble
        eval_body @mod, :module_eval, &body
        @mod
      end

      def create_module(parent_module, name)
        mod = Module.new
        if name && @conf.create_const
          SDGUtils::MetaUtils.assign_const_in_module(parent_module, name, mod)
        end
        mod
      end

      #-------------------------------------------------------------------
      # Creates a new module and assigns it to a given constant name,
      # or returns an existing one.
      #
      #  * if +name+ is +nil+ or empty, returns the module of +self+
      #  * if constant with named +name+ is already defined,
      #    * if the existing constant is a +Module+, returns that module
      #    * else, raises NameError
      #  * else, creates a new module
      #-------------------------------------------------------------------
      def create_or_get_module(name)
        parent_module = @conf.parent_module
        mods_to_include = @conf.mods_to_include
        already_def = parent_module.const_defined?(name, false) rescue false
        ret_module = (parent_module.const_get name if already_def) ||
                     create_module(parent_module, name)

        raise NameError, "Constant #{name} already defined in module #{parent_module}"\
          unless ret_module.class == Module

        mods_to_include.each do |m|
          if ret_module.respond_to? @conf.include_module_mthd, true
            safe_send ret_module, @conf.include_module_mthd, m
          else
            ret_module.send(:include, m) unless ret_module.include? m
            ret_module.send(:extend, m)
          end
        end # unless ret_module == Object

        ret_module
      end

    end

  end
end
