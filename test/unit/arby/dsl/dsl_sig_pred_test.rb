require 'my_test_helper'

require 'arby/helpers/test/dsl_helpers'
require 'arby/initializer.rb'
require 'arby/dsl/errors'
require 'sdg_utils/lambda/proc'

include Arby::Dsl

module A_D_SPT
  alloy_model do
    sig S1 do
      def ruby_meth_no_arg()    end
      def ruby_meth_args(x, y)  end
      def ruby_meth_varargs(*a) end
    end

    sig S2 do
      fun :name => "f1", :args => {a: S1, b: S2}, :ret_type => Int do |a,b| a + b end
      fun :f2, a: S1, b: S2, _: Int do |a,b| a + b end
      fun :f3, {a: S1, b: S2}, Int do |a,b| a + b end
    end

    sig S3 do
      fun f1[a: S1, b: S2][Int] {
        a + b
      }
      fun f2[a: S1, b: S2][Int] { |a, b|
        a + b
      }
      fun f3[:a, :b] {
        a + b
      }
      fun f4[:a, :b][S3] {
        a + b
      }
      fun f5[[:a, :b] => S3][S3] {
        a + b
      }
      fun f6[[a, b] => Int] {
        a + b
      }
    end

    sig S4 do
      pred p1[a: S1, b: S2] {
        a && b
      }
      pred p2[a: S3, b: S4] { |a, b|
        a && b
      }
      pred p3[:a, :b] {
        a && b
      }
      pred p4[:a, :b][Bool] {
        a && b
      }
    end
  end
end

class String
  include SDGUtils::Lambda::Str2Proc
end

class DslPredTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions

  include A_D_SPT

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(A_D_SPT)
    Arby.initializer.init_all_no_freeze
  end

  def notype() Arby::Ast::NoType.new end

  def atype
    lambda {|cls| Arby::Ast::AType.get!(cls)}
  end

  def get_funs(sig)
    sig.meta.funs.reduce({}){|acc,f|
      assert_equal sig, f.owner
      acc.merge!({f.name => f})
    }
  end

  def get_preds(sig)
    sig.meta.preds.reduce({}){|acc,f| acc.merge!({f.name => f})}
  end

  def amodel(&block)
    Arby.conf.do_with :defer_body_eval => false do
      alloy_model &block
    end
  end

  def check_arg_names(fun, arg_names)
    assert_seq_equal arg_names, fun.args.map(&:name)
  end

  def check_arg_types(fun, arg_types)
    expected = arg_types.map(&atype)
    assert_seq_equal expected, fun.args.map(&:type)
  end

  def check_fun(fun, arg_names, arg_types, ret_type)
    arg_types ||= fun.arity.times.map{Arby::Ast::NoType.new}
    ret_type ||= Arby::Ast::NoType.new
    check_arg_names(fun, arg_names)
    check_arg_types(fun, arg_types)
    assert_equal atype[ret_type], fun.ret_type
  end

  def test_invalid_body
    sname = "SigTmp"
    ex = assert_raise(Arby::Dsl::SyntaxError) do
      amodel do
        sig sname do
          fun f1[a: S1, b: S2][Int] { |a|
            a + b
          }
        end
      end
    end
    msg = "number of function `f1' formal parameters (2) doesn't match the arity " +
          "of the given block (1)"
    assert_starts_with msg, ex.message
  end

  def test_invalid_too_many_ret
    sname = "SigTmp"
    ex = assert_raise(Arby::Dsl::SyntaxError) do
      amodel do
        sig sname do
          fun f1[a: S1, b: S2][Int,String] {
            a + b
          }
        end
      end
    end
    assert_starts_with "can only specify 1 arg", ex.message
  end

  def test_invalid_after_ret
    sname = "SigTmp"
    ex = assert_raise(Arby::Dsl::SyntaxError) do
      amodel do
        sig sname do
          fun f1[a: S1, b: S2][Int][] {
            a + b
          }
        end
      end
    end
    assert_starts_with "only two calls to [] allowed", ex.message
  end

  def test_invalid_fname_not_string
    sname = "SigTmp"
    ex = assert_raise(Arby::Dsl::SyntaxError) do
      amodel do
        sig sname do
          fun S1, a: S1, b: S2, _: Int do |a,b| a + b end
        end
      end
    end
    assert_starts_with "`A_D_SPT::S1' (function name) is not a valid identifier", ex.message
    sname = "SigTmp"
    ex = assert_raise(Arby::Dsl::SyntaxError) do
      amodel do
        sig sname do
          fun 1, a: S1, b: S2, _: Int do |a,b| a + b end
        end
      end
    end
    assert_starts_with "`1' (function name) is not a valid identifier", ex.message
  end

  def test_invalid_argname_not_string
    sname = "SigTmp"
    ex = assert_raise(Arby::Dsl::SyntaxError) do
      amodel do
        sig sname do
          fun f1[S1: S1][Int] {
            a + b
          }
        end
      end
    end
    assert_starts_with "`S1' (arg name) is not a valid identifier", ex.message
  end

  def test_invalid_pred_rettype
    sname = "SigTmp"
    ex = assert_raise(Arby::Dsl::SyntaxError) do
      amodel do
        sig sname do
          pred f1[s1: S1][Int] {
            a + b
          }
        end
      end
    end
    assert_starts_with "expected bool return type, got Int", ex.message
  end

  def test_invalid_pred_empty_rettype
    sname = "SigTmp"
    ex = assert_raise(Arby::Dsl::SyntaxError) do
      amodel do
        sig sname do
          pred f1[s1: S1][] {
            a + b
          }
        end
      end
    end
    assert_starts_with "can only specify 1 arg for return type", ex.message
  end

  def test1
    funs = get_funs S1
    assert_set_equal [:ruby_meth_no_arg, :ruby_meth_args, :ruby_meth_varargs], funs.keys
    check_arg_names funs[:ruby_meth_no_arg],  []
    check_arg_names funs[:ruby_meth_args],    [:x, :y]
    check_arg_names funs[:ruby_meth_varargs], [:a]
  end

  def test2
    funs = get_funs S2
    assert_set_equal [:f1, :f2, :f3], funs.keys

    check_fun funs[:f1], [:a, :b], [S1, S2], Integer
    assert_equal 2, S2.new.f1(1,1)

    check_fun funs[:f2], [:a, :b], [S1, S2], Integer
    assert_equal 2, S2.new.f2(1,1)

    check_fun funs[:f3], [:a, :b], [S1, S2], Integer
    assert_equal 2, S2.new.f3(1,1)
  end

  def test3
    funs = get_funs S3
    assert_set_equal [:f1, :f2, :f3, :f4, :f5, :f6], funs.keys

    check_fun funs[:f1], [:a, :b], [S1, S2], Integer
    assert_equal 2, S3.new.f1(1,1)

    check_fun funs[:f2], [:a, :b], [S1, S2], Integer
    assert_equal 4, S3.new.f2(3,1)

    check_fun funs[:f3], [:a, :b], nil, nil
    assert_equal 5, S3.new.f3(3,2)

    check_fun funs[:f4], [:a, :b], nil, S3
    assert_equal 8, S3.new.f4(6,2)

    check_fun funs[:f5], [:a, :b], [S3, S3], S3
    assert_equal 10, S3.new.f5(6,4)

    check_fun funs[:f6], [:a, :b], [:Int, :Int], nil
    assert_equal 10, S3.new.f6(6,4)
  end

  def test4
    funs = get_preds S4
    assert_set_equal [:p1, :p2, :p3, :p4], funs.keys

    check_fun funs[:p1], [:a, :b], [S1, S2], :Bool
    assert_equal 4, S4.new.p1(1, 4)

    check_fun funs[:p2], [:a, :b], [S3, S4], :Bool
    assert_equal nil, S4.new.p2(1, nil)

    check_fun funs[:p3], [:a, :b], nil, :Bool
    assert_equal nil, S4.new.p3(nil, 3)

    check_fun funs[:p4], [:a, :b], nil, :Bool
    assert_equal nil, S4.new.p4(nil, 3)
  end

end
