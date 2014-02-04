require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/util/relation'

class RelationTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Relation = ArbyModels::AlloySample::Util::Relation
  include Relation

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Relation)
  end

  def test_als
    # puts Relation.meta.to_als
    assert Relation.compile
  end
end
