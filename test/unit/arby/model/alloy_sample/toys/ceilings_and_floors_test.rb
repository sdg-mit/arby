require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/toys/ceilings_and_floors'

class CeilingsAndFloorsTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  CeilingsAndFloors = ArbyModels::AlloySample::Toys::CeilingsAndFloors
  include CeilingsAndFloors

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(CeilingsAndFloors)
  end

  def test_als
    # puts CeilingsAndFloors.meta.to_als
    assert CeilingsAndFloors.compile
  end

  def test_check_belowToo
    sol = CeilingsAndFloors.exe_cmd :belowToo
    assert sol.satisfiable?
  end

  def test_check_belowToo2
    sol = CeilingsAndFloors.exe_cmd 1
    assert !sol.satisfiable?
    sol = CeilingsAndFloors.exe_cmd 2
    assert sol.satisfiable?
  end

  def test_check_belowToo3
    sol = CeilingsAndFloors.exe_cmd 3
    assert !sol.satisfiable?
    sol = CeilingsAndFloors.exe_cmd 4
    assert !sol.satisfiable?
  end
end
