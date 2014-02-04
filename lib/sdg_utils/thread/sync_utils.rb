require 'monitor'

module SDGUtils
  module Thread

    # Usage: extend your class/module with this module
    #
    # *IMPORTANT*: if defining +initialize+, don't forget to call
    #              +super()+ to initialize the monitor.
    module Sync
      def self.extended(cls)
        cls.send :include, MonitorMixin
      end

      def sync_block
        fail "+self+ is not a +Module+" unless Module === self
        pre_inst_methods = self.instance_methods(false)
        yield
        post_inst_methods = self.instance_methods(false)
        diff = post_inst_methods.select {|m| !pre_inst_methods.member?(m)}
        diff.each do |meth|
          sync_meth meth
        end
      end

      def sync_meth(meth)
        orig = "_#{meth.to_s}".to_sym
        puts "+++ synchronized #{self}\##{meth}"
        self.send :alias_method, orig, meth
        self.send :define_method, meth, lambda{|*args| synchronize{send orig, *args}}
      end

      def sync_all(inherited=false)
        self.instance_methods(inherited).each {|m| sync_meth(m)}
      end
    end

  end
end
