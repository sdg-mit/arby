require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/toys/numbering'

class NumberingTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Numbering = ArbyModels::AlloySample::Toys::Numbering
  include Numbering

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Numbering)
  end

  def test_als
    # puts Numbering.meta.to_als
    assert Numbering.compile
  end

  def test_check_preserveForest
    sol = Numbering.check_preserveForest
    assert !sol.satisfiable?, "expected unsat, i.e., no counterexample for preserveForest"
  end

  def test_check_addNeverReduces
    sol = Numbering.check_addNeverReduces
    assert sol.satisfiable?, "expected sat, i.e., counterexample for addNeverReduces"
  end
end
