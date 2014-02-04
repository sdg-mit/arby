module Arby
  module Bridge
    module SolverHelpers

      def compile
        require 'arby/bridge/compiler'
        Arby::Bridge::Compiler.compile(self)
      end

      def solve(*pred_scope_bounds, &block)
        require 'arby/bridge/compiler'
        require 'arby/bridge/solution'

        if !block
          pred = pred_scope_bounds[0]
          scope_bounds = pred_scope_bounds[1..-1]
        else
          pred = nil
          scope_bounds = pred_scope_bounds
        end

        grps = scope_bounds.group_by{|e| e.is_a? Arby::Ast::Bounds}
        bounds = Array(grps[true]).first
        scope = Arby::Dsl::CommandHelper.parse_scope(self, *Array(grps[false]))

        Arby::Bridge::Compiler.solve(self, pred, scope, bounds)
      end

      def execute_command(cmd_idx_or_name=0, bounds=nil)
        require 'arby/bridge/compiler'
        Arby::Bridge::Compiler.execute_command(self, cmd_idx_or_name, bounds)
      end

      alias_method :exe_cmd, :execute_command

      def find_instance(pred=nil, *scope_bounds)
        sol = solve(pred, *scope_bounds)
        if sol.satisfiable?
          sol.arby_instance
        else
          nil
        end
      end

    end
  end
end
