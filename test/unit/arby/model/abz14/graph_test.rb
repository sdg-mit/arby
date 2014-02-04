require 'my_test_helper'
require 'arby_models/abz14/graph'

class ABZ14GraphTest < Test::Unit::TestCase
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  GraphModel = ArbyModels::ABZ14::GraphModel
  include GraphModel

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(ArbyModels::ABZ14::GraphModel)
  end

  def test_als
    # puts GraphModel.meta.to_als
    assert GraphModel.compile
  end

  def test_exe_spec
    n1, n2 = Node.new, Node.new
    e = Edge.new src: n1, dst: n2
    g = Graph.new nodes: [n1, n2], edges: [e]
    hp = g.find_hampath # => [n1, n2]
    assert_equal [n1, n2], hp.unwrap

    hp = g.hampath.project(1) # => [n1, n2]
    assert_equal [n1, n2], hp.unwrap
  end

  def test_run_hampath
    sol = GraphModel.run_hampath
    assert sol.satisfiable?
    assert graph = sol["$hampath_g"]
    assert path  = sol["$hampath_path"]
    puts graph.nodes
    puts graph.edges
    puts path.project(1)
  end

  def test_check_reach
    sol = GraphModel.check_reach
    assert !sol.satisfiable? # assertion holds
  end

  def test_check_uniq
    sol = GraphModel.check_uniq
    assert !sol.satisfiable? # assertion holds
  end

end
