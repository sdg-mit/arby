require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/toys/life'

class LifeTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Life = ArbyModels::AlloySample::Toys::Life
  include Life

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Life)
  end

  def test_als
    # puts Life.meta.to_als
    assert Life.compile
  end

  def test_run_interesting
    sol = Life.run_interesting
    assert sol.satisfiable?
  end

  def test_run_square
    sol = Life.run_square
    assert sol.satisfiable?
  end

  def test_run_show
    sol = Life.run_show
    assert sol.satisfiable?
  end

end
