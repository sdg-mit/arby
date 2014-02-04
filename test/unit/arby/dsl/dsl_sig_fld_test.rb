require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'
require 'arby/initializer.rb'

include Arby::Dsl

module DSLFLDTEST
  alloy_model do
    sig S
  end

  alloy_model "Users" do
    sig SBase do
      abstract
    end

    sig SigA < SBase, {
      f0: SigA * SBase,

      f4: (one SigA * SBase),
      f5: (set SigA * String * SBase),
      f6: (seq String * SigA),

      g1: one/SigA * SBase,
      g2: set/SigA * (one SigA * String),
      g3: seq/SigA,
    }
  end

  alloy_module "Users" do
    sig SigB < SigA, {
      x: SigB
    }

    sig SigC < SigA
  end
end

# puts Users::SBase.to_alloy
# puts Users::SigA.to_alloy
# puts Users::SigB.to_alloy

class DslTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(DSLFLDTEST)
    Arby.initializer.init_all_no_freeze
  end

  def test_sigs_defined
    sig_test_helper('DSLFLDTEST::Users::SBase', Arby::Ast::Sig)
    sig_test_helper('DSLFLDTEST::Users::SigA', DSLFLDTEST::Users::SBase)
    sig_test_helper('DSLFLDTEST::Users::SigB', DSLFLDTEST::Users::SigA)
  end

  def test_fld_accessors_defined
    fld_acc_helper(DSLFLDTEST::Users::SBase, [])
    fld_acc_helper(DSLFLDTEST::Users::SigA, %w(f0 f4 f5 f6 g1 g2 g3))
    fld_acc_helper(DSLFLDTEST::Users::SigB, %w(x))
  end

  def test_inv_fld_accessors_defined
    inv_fld_acc_helper(DSLFLDTEST::Users::SBase, %w(f0 g1 f4 f5))
    inv_fld_acc_helper(DSLFLDTEST::Users::SigA, %w(f6 g3))
    inv_fld_acc_helper(DSLFLDTEST::Users::SigB, %w(x))
  end

  def test_subsigs_discovered
    subsig_test_helper(DSLFLDTEST::Users::SBase, [DSLFLDTEST::Users::SigA])
    subsig_test_helper(DSLFLDTEST::Users::SigA, [DSLFLDTEST::Users::SigB, DSLFLDTEST::Users::SigC])
    subsig_test_helper(DSLFLDTEST::Users::SigB, [])
  end

  def test_oldest_ancestor
    assert_equal nil, DSLFLDTEST::Users::SBase.oldest_ancestor
    assert_equal nil, DSLFLDTEST::Users::SBase.oldest_ancestor(false)
    assert_equal nil, DSLFLDTEST::Users::SBase.oldest_ancestor(true)

    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SigA.oldest_ancestor
    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SigA.oldest_ancestor(false)
    assert_equal nil, DSLFLDTEST::Users::SigA.oldest_ancestor(true)

    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SigB.oldest_ancestor
    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SigB.oldest_ancestor(false)
    assert_equal DSLFLDTEST::Users::SigA, DSLFLDTEST::Users::SigB.oldest_ancestor(true)

    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SigC.oldest_ancestor
    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SigC.oldest_ancestor(false)
    assert_equal DSLFLDTEST::Users::SigA, DSLFLDTEST::Users::SigC.oldest_ancestor(true)
  end

  def test_root
    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SBase.alloy_root
    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SigA.alloy_root
    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SigB.alloy_root
    assert_equal DSLFLDTEST::Users::SBase, DSLFLDTEST::Users::SigC.alloy_root
  end

  def test_all_subsigs
    assert_set_equal [DSLFLDTEST::Users::SigA, DSLFLDTEST::Users::SigB, DSLFLDTEST::Users::SigC], DSLFLDTEST::Users::SBase.all_subsigs
    assert_set_equal [DSLFLDTEST::Users::SigB, DSLFLDTEST::Users::SigC], DSLFLDTEST::Users::SigA.all_subsigs
    assert_set_equal [], DSLFLDTEST::Users::SigB.all_subsigs
    assert_set_equal [], DSLFLDTEST::Users::SigC.all_subsigs
  end

end
