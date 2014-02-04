require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/systems/file_system'

class FileSystemTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  FileSystem = ArbyModels::AlloySample::Systems::FileSystem
  include FileSystem

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(FileSystem)
  end

  def test_als
    # puts FileSystem.meta.to_als
    assert FileSystem.compile
  end

  def test_check_buggy
    sol = FileSystem.exe_cmd :buggy
    assert sol.satisfiable?
  end

  def test_check_correct
    sol = FileSystem.exe_cmd :correct
    assert !sol.satisfiable?
  end

end
