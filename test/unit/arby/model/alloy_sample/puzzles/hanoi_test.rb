require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/puzzles/hanoi'

class HanoiTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Hanoi = ArbyModels::AlloySample::Puzzles::Hanoi
  include Hanoi

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Hanoi)
  end

  def test_als
    # puts Hanoi.meta.to_als
    assert Hanoi.compile
  end

  def test_run_game1
    sol = Hanoi.run_game1
    assert sol.satisfiable?
  end

  def test_run_game2
    sol = Hanoi.run_game2
    assert sol.satisfiable?
  end

end
