module SDGUtils
  module Lambda

    module ToProc
      extend self
      def cls_to_new_proc(cls)
        proc{|*args| cls.new(*args)}
      end

      def str_to_deref_proc(str)
        refs = str.split(".")
        lambda{|obj| refs.reduce(obj){|ans, mth| ans.send mth.to_sym}}
      end

      alias_method :deref, :str_to_deref_proc
      alias_method :deref_proc, :str_to_deref_proc
    end

    # extend this module from a class to define to proc coercion
    # methods for your class
    module Class2Proc
      def to_constr_proc() ToProc.cls_to_new_proc(self) end
      alias_method :constr_proc, :to_constr_proc
      alias_method :cstr_proc, :to_constr_proc
    end
    
    # extend this module from a class to define to proc coercion
    # methods for your class
    module Str2Proc
      def deref_proc() ToProc.str_to_deref_proc(to_s) end
    end

  end
end
