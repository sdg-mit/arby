require 'arby/ast/expr.rb'
require 'arby/ast/types'
require 'arby/ast/type_checker'
require 'arby/ast/utils'

module Arby
  module Ast

    # ============================================================================
    # == Class +Fun+
    #
    # Represents function definitions
    #
    # @attr :owner    [ASig, Model]
    # @attr :name     [Symbol]
    # @attr :args     [Array(Arg)]
    # @attr :ret_type [AType]
    # ============================================================================
    class Fun
      include Checks

      attr_reader :kind, :owner, :name, :arby_method_name, :args, :ret_type, :body

      class << self

        # ~~~~~~~~~~~~~~~~ factory methods ~~~~~~~~~~~~~~~~  #

        def fun(hash)
          Fun.new(:fun, hash)
        end

        def pred(hash)
          hash = ensure_bool_ret(hash.clone)
          Fun.new(:pred, hash)
        end

        def fact(hash)
          hash = ensure_bool_ret(hash.clone)
          hash = ensure_no_args(hash)
          Fun.new :fact, hash
        end

        def assertion(hash)
          hash = ensure_bool_ret(hash.clone)
          hash = ensure_no_args(hash)
          Fun.new :assertion, hash
        end

        def procedure(hash)
          Fun.new(:procedure, hash)
        end

        def for_method(owner, method_name)
          meth = owner.instance_method(method_name)
          body = meth.bind(Fun.dummy_instance(owner)).to_proc
          fun :name     => method_name,
              :args     => proc_args(meth),
              :ret_type => TypeConsts::None,
              :owner    => owner,
              :body     => body
        end

        # ~~~~~~~~~~~~~~~~ utils ~~~~~~~~~~~~~~~~  #

        # @param cls [Class, Module]
        def dummy_instance(cls)
          if Class === cls
            Arby::Ast::TypeChecker.check_sig_class!(cls)
            if cls < SDGUtils::MNested
              parent = dummy_instance(cls.__parent())
              parent.allocate(cls)
            else
              cls.send :allocate
            end
          else # it must be a Module
            Arby::Ast::TypeChecker.check_arby_module!(cls)
            obj = Object.new
            obj.singleton_class.send :include, cls
            obj.define_singleton_method :make_me_sym_expr do |name="self"|
              Expr.as_atom(self, name, cls, Expr::MImplicitInst)
            end
            obj
          end
        end

        def dummy_instance_expr(cls, name="self")
          inst = dummy_instance(cls)
          inst.make_me_sym_expr(name)
          inst
        end

        def proc_args(proc)
          return [] unless proc
          proc.parameters.map{ |mod, sym|
            Arby::Ast::Arg.new :name => sym,
                                :type => Arby::Ast::NoType.new
          }
        end

        private

        def ensure_bool_ret(hash)
          rt = hash[:ret_type]
          unless rt.nil? || Arby::Ast::NoType === rt
            at = Arby::Ast::AType.get!(rt)
            msg = "expected bool return type, got #{at}"
            raise ArgumentError, msg unless (at.isBool? rescue false)
          end
          hash[:ret_type] = :Bool
          hash
        end

        def ensure_no_args(hash)
          args = hash[:args]
          msg = "expected no arguments"
          raise ArgumentError, msg unless args.nil? || args.empty?
          hash[:args] = []
          hash
        end
      end

      private

      def initialize(kind, hash)
        @kind              = kind
        @owner             = hash[:owner]
        @name              = check_iden hash[:name].to_s.to_sym, "function name"
        @arby_method_name = "#{@name}_alloy"
        @args              = hash[:args] || []
        @ret_type          = Arby::Ast::AType.get!(hash[:ret_type])
        @body              = hash[:body]
      end

      public

      def fun?()       @kind == :fun  end
      def pred?()      @kind == :pred  end
      def fact?()      @kind == :fact  end
      def assertion?() @kind == :assertion  end
      def procedure?() @kind == :procedure  end

      def arity()      args.size end
      def arg_types()  args.map(&:type) end
      def full_type()  (arg_types + [ret_type]).reduce(nil, &ProductType.cstr_proc) end
      def full_name()  "#{owner}.#{name}" end

      def arg(name)    args.find {|a| a.name == name} end

      def sym_exe(inst_name="self")
        target = Fun.dummy_instance_expr(@owner, inst_name)
        __sym_exe(target)
      end

      def to_opts
        instance_variables.reduce({}) do |acc,sym|
          acc.merge!({sym[1..-1].to_sym => instance_variable_get(sym)})
        end
      end

      def to_s
        args_str = args.map{|a| "#{a.name}: #{a.type}"}.join(", ")
        blk_str = body ? " do ... end" : ""
        "#{@kind} #{name} [#{args_str}]: #{ret_type}#{blk_str}"
      end

      protected

      def __sym_exe(target)
        mode = Arby.exe_mode
        Arby.set_symbolic_mode
        vars = args.map{|a| Arby::Ast::Expr::Var.new(a.name, a.type)}
        target.send arby_method_name.to_sym, *vars
      ensure
        Arby.restore_exe_mode(mode)
      end
    end

  end
end
