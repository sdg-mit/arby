require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/toys/railway'

class RailwayTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Railway = ArbyModels::AlloySample::Toys::Railway
  include Railway

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Railway)
  end

  def test_als
    # puts Railway.meta.to_als
    assert Railway.compile
  end

  def test_check_policyWorks
    sol = Railway.check_policyWorks
    assert sol.satisfiable?
  end

  def test_run_trainsMoveLegal
    sol = Railway.run_trainsMoveLegal
    assert sol.satisfiable?
  end

  # def test_check_belowToo3
  #   sol = Railway.exe_cmd 3
  #   assert !sol.satisfiable?
  #   sol = Railway.exe_cmd 4
  #   assert !sol.satisfiable?
  # end
end
