require 'my_test_helper'
require 'arby/ast/expr_builder'
require 'arby/arby_dsl'

include Arby::Dsl

alloy :A_A_EBT do
  sig SigA [ intFld: Int ]
  sig SigB
  sig SubA
  sig SubB
end

module Arby
  module Ast

    class ExprBuilderTest < Test::Unit::TestCase
      include SDGUtils::Testing::Assertions
      include SDGUtils::Testing::SmartSetup

      include Arby::Ast::Ops
      include A_A_EBT

      def setup_class
        Arby.reset
        Arby.meta.restrict_to(A_A_EBT)
        Arby.initializer.init_all_no_freeze
      end

      def setup_test
        @curr_exe_mode = Arby.exe_mode
        Arby.set_symbolic_mode
      end

      def teardown
        Arby.restore_exe_mode(@curr_exe_mode)
      end

      def apply(*args)
        ExprBuilder.apply(*args)
      end

      def assert_type(type_array, expr)
        assert expr.respond_to?(:__type), "Expr `#{expr}' doesn't respond to __type"
        t = expr.__type
        assert t, "Expr `#{expr}' type is nil"
        type_array = type_array.map(&Arby::Ast::AType.method(:get))
        assert_equal type_array.size, t.arity,
                     "Expected arity #{type_array.size}, actual #{t.arity}\n" +
                     "lhs = #{type_array}; rhs = #{t}"
        assert_seq_equal type_array, t.columns
      end

      def test_product
        lhs = SigA.to_arby_expr
        rhs = SigB.to_arby_expr
        ans = apply(PRODUCT, lhs, rhs)
        assert Expr::BinaryExpr === ans
        assert_equal PRODUCT, ans.op
        assert_equal lhs, ans.lhs
        assert_equal rhs, ans.rhs
        assert_type [SigA, SigB], ans
      end

      def test_cardinality
        sub = SigA.to_arby_expr
        ans = apply(CARDINALITY, sub )
        assert Expr::UnaryExpr === ans
        assert_equal CARDINALITY, ans.op
        assert_type [:Integer], ans
      end

      def test_select
        lhs = SigA
        rhs = SigB
        ans = apply(SELECT, lhs, rhs)
        assert Expr::BinaryExpr === ans
        assert_equal SELECT, ans.op
        assert_type [], ans

        ans = apply(SELECT, apply(PRODUCT, lhs, rhs), lhs)
        assert_equal SELECT, ans.op
        assert_type [SigB], ans
      end

      #TODO: fix code so that these pass
      def _test_plus_1() assert_type [SigA], apply(PLUS, SigA, SubA) end
      def test_plus_2() assert_type [SigA], apply(PLUS, SubA, SigA) end
      def test_plus_3() assert_type [SigA], apply(PLUS, SigA, SigA) end
      def _test_plus_4() assert_type [Sig], apply(PLUS, SigA, SigB) end
      def _test_plus_5() assert_type [Sig], apply(PLUS, SubA, SigB) end
      def _test_plus_6() assert_type [Sig], apply(PLUS, SigA, SubB) end

      def _test_intersect_1() assert_type [SubA], apply(INTERSECT, SigA, SubA) end
      def test_intersect_2() assert_type [SubA], apply(INTERSECT, SubA, SigA) end
      def test_intersect_3() assert_type [SigA], apply(INTERSECT, SigA, SigA) end
      def _test_intersect_4() assert_type [], apply(INTERSECT, SigA, SigB) end
      def _test_intersect_5() assert_type [], apply(INTERSECT, SubA, SigB) end
      def _test_intersect_6() assert_type [], apply(INTERSECT, SigA, SubB) end

      def test_minus_1() assert_type [SigA], apply(MINUS, SigA, SubA) end
      def test_minus_2() assert_type [SubA], apply(MINUS, SubA, SigA) end
      def test_minus_3() assert_type [SigA], apply(MINUS, SigA, SigA) end
      def test_minus_4() assert_type [SigA], apply(MINUS, SigA, SigB) end
      def test_minus_5() assert_type [SubA], apply(MINUS, SubA, SigB) end
      def test_minus_6() assert_type [SigA], apply(MINUS, SigA, SubB) end

      def test_transpose
        sub = SigA.to_arby_expr
        ans = apply(TRANSPOSE, sub)
        assert Expr::UnaryExpr === ans
        assert_equal TRANSPOSE, ans.op
      end

      def test_equality_ops
        ops = [EQUALS, NOT_EQUALS]
        ops.each do |op|
          lhs, rhs = 2, 2
          ans = apply(op,lhs,rhs)
          assert Expr::BinaryExpr === ans
          assert_equal op, ans.op
          assert_equal lhs, ans.lhs
          assert_equal rhs, ans.rhs
          assert_type [:Bool], ans
        end
      end

      def test_in_not_in_ops
        ops = [IN, NOT_IN]
        ops.each do |op|
          lhs, rhs = SigA.to_arby_expr, 1
          ans = apply(op,lhs,rhs)
          assert Expr::BinaryExpr === ans
          assert_equal op, ans.op
          assert_equal lhs, ans.lhs
          assert_equal rhs, ans.rhs
          assert_type [:Bool], ans
        end
      end

      def test_int_size_equality_ops
        ops = [LT, LTE, GT, GTE, NOT_LT, NOT_LTE, NOT_GT, NOT_GTE]
        ops.each do |op|
          lhs, rhs = 2, 3
          ans = apply(op, lhs, rhs)
          assert Expr::BinaryExpr === ans
          assert_equal op, ans.op
          assert_equal lhs, ans.lhs
          assert_equal rhs, ans.rhs
          assert_type [:Bool], ans
        end
      end

      def _quant_ops
        ops =[ALLOF, SOMEOF, NONEOF, ONEOF, LONEOF]
        ops.each do |op|
          decl = {a: SigA}
          body = Expr::Var.new("a", SigA).some?
          ans = apply(op, decl, body)
          assert Expr::QuantExpr === ans
          assert_type [:Bool], ans
        end
      end

      def test_int_bin_ops
        ops = [REM, IPLUS, IMINUS, DIV, MUL, PLUSPLUS]
        ops.each do |op|
          lhs, rhs = 5, 3
          ans = apply(op, lhs, rhs)
          assert Expr::BinaryExpr === ans
          assert_equal op, ans.op
          assert_equal lhs, ans.lhs
          assert_equal rhs, ans.rhs
          assert_type [:Integer], ans
        end
      end

      def test_shift_ops
        ops = [SHL, SHA, SHR]
        ops.each do |op|
          lhs, rhs = 10001, 2
          ans = apply(op, lhs, rhs)
          assert Expr::BinaryExpr === ans
          assert_equal op, ans.op
          assert_equal lhs, ans.lhs
          assert_equal rhs, ans.rhs
          assert_type [:Integer], ans
        end
      end

      def test_and_or_ops
        ops = [AND, OR]
        ops.each do |op|
          lhs, rhs = 2 ,1
          ans = apply(op, rhs, lhs) #figure out why true/false is not working
          assert Expr::BinaryExpr === ans
          assert_equal op, ans.op
          assert_equal lhs, ans.lhs
          assert_equal rhs, ans.rhs
          assert_type [:Bool], ans
        end
      end

      def test_iff_implies
        ops = [IFF, IMPLIES]
        ops.each do |op|
          lhs, rhs = 2 ,1 #figure out what goes in here
          ans = apply(op, rhs, lhs)
          assert Expr::BinaryExpr === ans
          assert_equal op, ans.op
          assert_equal lhs, ans.lhs
          assert_equal rhs, ans.rhs
          assert_type [:Bool], ans
        end
      end

      def test_transpose_op
        expr = apply(PRODUCT, SigA, SigB)
        assert_type [SigA, SigB], expr
        ans = apply(TRANSPOSE, expr)
        assert_type [SigB, SigA], ans
      end

      def test_sum_op
        decl = [Arg.new("a", SigA)]
        body = Expr::Var.new("a", SigA).intFld
        ans = apply(SUM, decl, body)
        assert Expr::QuantExpr === ans
        assert_type [:Integer], ans
      end

      def test_unknown
        assert_raise(ArgumentError) do
          apply(UNKNOWN, 1, 2)
          apply(NOOP, 1)
        end
      end
    end
  end
end
