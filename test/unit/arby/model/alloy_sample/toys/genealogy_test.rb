require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/toys/genealogy'

class GenealogyTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Genealogy = ArbyModels::AlloySample::Toys::Genealogy
  include Genealogy

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Genealogy)
  end

  def test_als
    # puts Genealogy.meta.to_als
    assert Genealogy.compile
  end

  def test_run_show
    sol = Genealogy.run_show
    assert sol.satisfiable?
  end
end
