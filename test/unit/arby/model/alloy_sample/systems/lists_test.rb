require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/systems/lists'

class ListsTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Lists = ArbyModels::AlloySample::Systems::Lists
  include Lists

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Lists)
  end

  def test_als
    # puts Lists.meta.to_als
    assert Lists.compile
  end

  def test_check_reflexive
    sol = Lists.check_reflexive
    assert !sol.satisfiable?
  end

  def test_check_symmetric
    sol = Lists.check_symmetric
    assert !sol.satisfiable?
  end

  def test_check_empties
    sol = Lists.check_empties
    assert !sol.satisfiable?
  end

  def test_run_show
    sol = Lists.run_show
    assert sol.satisfiable?
  end
end
