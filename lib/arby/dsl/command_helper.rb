require 'arby/ast/command'
require 'arby/ast/fun'
require 'arby/ast/scope'
require 'arby/dsl/errors'
require 'arby/utils/codegen_repo'

module Arby
  module Dsl

    # REQUIREMENTS
    #   FunHelper included
    #   meta.checks
    #   meta.add_check
    #   meta.runs
    #   meta.add_run
    module CommandHelper
      def check(*name_and_scope, &body)
        __command(:check, *name_and_scope, &body)
      end

      def run(*name_and_scope, &body)
        if caller[0].end_with?("block in _run_suite'")
          super
        else
          __command(:run, *name_and_scope, &body)
        end
      end

      def self.parse_scope(model, *args)
        raise SyntaxError, "Invalid scope syntax.  " +
          "Too many arguments: expected <=2, got #{args.size}." if args.size > 2
        global = nil
        exceptions = {}
        args.each {|e| e.is_a?(Hash) ? exceptions = e : global = e}

        global = global.gsub(/^for /, "") if global.is_a?(String)
        global = 4 if global.to_s.empty?
        sig_scopes = __parse_sig_scope_hash(model, exceptions)
        Arby::Ast::Scope.new(global, sig_scopes)
      end

      def self.__parse_sig_scope_hash(model, hash={})
        resolve_str = lambda{|str| (model || Arby.meta).find_sig(str)}

        hash.map do |sig_spec, scope|
          sig = case sig_spec
                when String, Symbol then sig = resolve_str[sig_spec]
                when Class          then (sig_spec < Arby::Ast::ASig) ?
                                          sig_spec                    :
                                          resolve_str[sig_spec.relative_name]
                else
                  "Int" if sig_spec == Arby::Ast::TypeConsts::Int
                end
          sig or raise SyntaxError, "Invalid sig #{sig_spec}:#{sig_spec.class}"

          case scope
          when Arby::Ast::SigScope
            Arby::Ast::SigScope.new(sig || scope.sig, scope.scope, scope.exact?)
          when Integer
            Arby::Ast::SigScope.new(sig, scope)
          else
            raise SyntaxError, "Invalid scope #{scope}:#{scope.class}"
          end
        end
      end

      private

      def __command(kind, *name_scope_exceptions, &body)
        msg = "Too many commmand args: expected max 3, got #{name_scope_exceptions.size}"
        raise SyntaxError, msg if name_scope_exceptions.size > 3
        msg = "Too few command args: at least <scope> expected, got nothing"
        raise SyntaxError, msg if name_scope_exceptions.empty? && !body

        scope, name = []
        exceptions = {}
        name_scope_exceptions.each do |x|
          case x
          when String, Symbol then !name ? name = x : scope = x
          when Integer        then scope = x
          when Hash           then exceptions = x
          else
            raise SyntaxError, "Unexpected argument type: " +
              "expected String, Integer, or Hash, got #{x}:#{x.class}"
          end
        end

        scope = CommandHelper.parse_scope(self.meta, scope, exceptions)
        __cmd(kind, name, scope, &body)
      end

      def __cmd(kind, name=nil, scope=nil, &body)
        pred_name = name || "#{kind}_#{meta.checks.size}"
        pred = nil
        if body
          pred = _create_fn(:pred, pred_name, {}, nil, &body)
          _define_method_for_fun(pred)
        else
          raise SyntaxError, "neither name nor body specified" unless name
          mname = "#{kind}_#{name}"
          __eval_meth mname, <<-RUBY, __FILE__, __LINE__+1
          def self.#{mname}(*args) exe_cmd #{name.inspect}, *args end
          RUBY
        end
        cmd = Arby::Ast::Command.new(kind, name, scope, pred)
        meta.add_command cmd
        cmd
      end

      def __eval_meth(name, src, file=nil, line=nil)
        Arby::Utils::CodegenRepo.module_safe_eval_method(self, name, src, file, line)
      end

    end

  end
end
