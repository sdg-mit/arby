require 'sdg_utils/dsl/module_builder'
require 'sdg_utils/meta_utils'

module SDGUtils
  module DSL

    #=========================================================================
    # == Class InstanceBuilder
    #
    #=========================================================================
    class InstanceBuilder
      def initialize(options={})
        @opts = {
          :parent_class         => nil,
          :builder_class        => nil,
          :include_builder_mods => [],
          :include_mods         => [],
          :created_cb           => [],
          :expand_name          => false,
          :create_const         => false,
        }.merge!(options)
        @opts[:created_cb] = Array[@opts[:created_cb]].flatten.compact
        raise ArgumentError, ":parent_class not specified" unless @opts[:parent_class]
      end

      # --------------------------------------------------------------
      # Creates a new class, subclass of `@opts[SUPERCLASS]',
      # creates a constant with a given +name+ in the callers
      # namespace and assigns the created class to it.
      # --------------------------------------------------------------
      def build(name, opts={}, &block)
        mod = SDGUtils::DSL::ModuleBuilder.get.scope_module rescue nil
        mod ||= SDGUtils::MetaUtils.caller_module
        cls = @opts[:parent_class]

        fullname = if @opts[:expand_name]
                     mod_name_prefix = (mod == ::Object) ? "" : "#{mod.name}::"
                     "#{mod_name_prefix}#{name}"
                   else
                     name
                   end

        obj = cls.new fullname, opts

        @opts[:created_cb].each { |cb| cb.call(obj) }

        if block
          blder_cls = @opts[:builder_class]

          # if blder_cls is specified, the target of instance_eval is
          # a fresh instance of that class, otherwise it is the newly
          # created object
          target = blder_cls ? blder_cls.new(obj) : obj

          # include all :include_mods and include_builder_mods to
          # target's singleton class, so that methods from those
          # modules take presedence over the methods defined in the
          # parent class
          (@opts[:include_mods] + @opts[:include_builder_mods]).each do |mmod|
            target.singleton_class.send :include, mmod
          end

          # evaluate the block
          target.instance_eval(&block)

          # uninclude all include_builder_mods by either undefining
          # methods from those modules or redirecting them to the
          # parent class
          @opts[:include_builder_mods].each do |mmod|
            mmod.instance_methods(false).each do |meth|
              super_meth = cls.instance_method(meth).bind(target) rescue nil
              if super_meth
                target.define_singleton_method meth, super_meth.to_proc
              else
                target.singleton_class.send :undef_method, meth
              end
            end
          end
        end

        if @opts[:create_const]
          SDGUtils::MetaUtils.assign_const_in_module mod, name, obj
        end

        return obj
      end
    end

  end
end
