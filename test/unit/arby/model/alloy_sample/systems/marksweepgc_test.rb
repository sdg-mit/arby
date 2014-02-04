require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/systems/marksweepgc'

class MarkSweepTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  MarkSweep = ArbyModels::AlloySample::Systems::MarkSweep
  include MarkSweep

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(MarkSweep)
  end

  def test_als
    # puts MarkSweep.meta.to_als
    assert MarkSweep.compile
  end

  def test_check_soundness1
    sol = MarkSweep.check_soundness1
    assert !sol.satisfiable?
  end

  def test_check_soundness2
    sol = MarkSweep.check_soundness2
    assert !sol.satisfiable?
  end

  def test_check_completeness
    sol = MarkSweep.check_completeness
    assert !sol.satisfiable?
  end
end
