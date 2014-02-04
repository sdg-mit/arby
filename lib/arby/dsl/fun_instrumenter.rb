require 'sdg_utils/lambda/sourcerer'

module Arby
  module Dsl

    class FunInstrumenter
      include SDGUtils::Lambda::Sourcerer

      def initialize(proc)
        @proc = proc
      end

      def instrument
        ast = parse_proc(@proc)
        return ["", ""] unless ast
        orig_src = read_src(ast)
        pending_pipe_ends = 0
        instr_src = reprint(ast) do |node, parent, anno|
          case node.type
          when :if then
            cond_src = compute_src(node.children[0], anno)
            then_src = compute_src(node.children[1], anno)
            else_src = compute_src(node.children[2], anno)
            if else_src.empty?
              "Arby::Ast::Expr::BinaryExpr.implies(" +
                "proc{#{cond_src}}, proc{#{then_src}}) "
            else
              "Arby::Ast::Expr::ITEExpr.new(" +
                "proc{#{cond_src}}, " +
                "proc{#{then_src}}, " +
                "proc{#{else_src}})"
            end
          when :and, :or then
            lhs_src = compute_src(node.children[0], anno)
            rhs_src = compute_src(node.children[1], anno)
            "Arby::Ast::Expr::BinaryExpr.#{node.type}(" +
              "proc{#{lhs_src}}, " +
              "proc{#{rhs_src}})"
          when :send then
            if pipe_bin_op?(node)
              if pending_pipe_ends > 0 || quant?(node.children[0])
                # binding.pry if compute_src(node, anno).strip.start_with?("all(t, t")
                lhs_src = compute_src(node.children[0], anno)
                rhs_src = compute_src(node.children[2], anno)
                if quant?(node.children[2]) && pipe_bin_op?(parent) &&
                    node.eql?(parent.children[0])
                  pending_pipe_ends += 1
                  "#{lhs_src} do\n #{rhs_src} "
                else
                  x = pending_pipe_ends
                  pending_pipe_ends = 0
                  "#{lhs_src} do\n #{rhs_src} \n end #{'end ' * x} "
                end
              end
            elsif bin_call_with_dot?(node, anno) &&
                [:<, :>, :*, :^].member?(node.children[1])
              lhs_src = compute_src(node.children[0], anno)
              rhs_src = compute_src(node.children[2], anno)
              case node.children[1]
              when :<, :>
                meth = (node.children[1] == :<) ? :domain : :range
                "#{lhs_src}.#{meth}(#{rhs_src})"
              when :*, :^
                meth = (node.children[1] == :*) ? :rclosure : :closure
                "#{lhs_src}.((#{rhs_src}).#{meth}())"
              end
            end
          else
            nil
          end
        end
        [orig_src, instr_src]
      end

      def lt_gt?(node)
        Parser::AST::Node === node and
          node.type == :send and
          node.children.size == 3 and
          (node.children[1] == :> || node.children[1] == :<)
      end

      def pipe_bin_op?(node)
        Parser::AST::Node === node and
          node.type == :send and
          node.children.size == 3 and
          node.children[1] == :|
      end

      def quant?(node)
        Parser::AST::Node === node and
          node.type == :send and
          node.children.size >= 3 and
          node.children[0] == nil and
          [:all, :some, :no, :one, :lone, :select, :exists].member? node.children[1]
      end
    end

  end
end
