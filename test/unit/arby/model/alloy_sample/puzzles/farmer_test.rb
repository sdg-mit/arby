require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/puzzles/farmer'

class FarmerTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  FarmerModel = ArbyModels::AlloySample::Puzzles::FarmerModel
  include FarmerModel

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(FarmerModel)
  end

  def test_als
    # puts FarmerModel.meta.to_als
    assert FarmerModel.compile
  end

  def test_run_solvePuzzle
    sol = FarmerModel.run_solvePuzzle
    assert sol.satisfiable?
  end

  def test_check_noQuantumObjects
    sol = FarmerModel.check_noQuantumObjects
    assert !sol.satisfiable?
  end

end
