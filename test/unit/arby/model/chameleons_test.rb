require 'my_test_helper'
require 'arby_models/chameleons'
require 'sdg_utils/timing/timer'

class ChameleonsTest < Test::Unit::TestCase
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  include ArbyModels::ChameleonExample
  include ArbyModels::ChameleonExample::Chameleons

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(ArbyModels::ChameleonExample)
    @@timer = SDGUtils::Timing::Timer.new
  end

  # def test_als
  #   # puts ChameleonsViz.meta.to_als
  # end

  def test_chameleon
    # puts Chameleons.meta.to_als
    sol = Chameleons.execute_command :some_meet
    assert sol.satisfiable?
    sol.arby_instance
  end

  def test_viz
    # puts Viz.meta.to_als
    inst = Viz.find_instance
    assert inst
  end

  def test_chameleon_viz
    # puts ChameleonsViz.meta.to_als
    sol = ChameleonsViz.execute_command :viz
    assert sol.satisfiable?
    sol.arby_instance
  end

  def test_staged
    n = 5
    puts "scope = #{n}"
    puts "solving chameleons..."
    ch_sol = @@timer.time_it {
      Chameleons.solve :some_meet, n, Chameleon => exactly(n-1)
    }
    t1 = @@timer.last_time
    puts "time: #{t1}"
    assert ch_sol.satisfiable?

    inst = ch_sol.arby_instance
    bounds = inst.to_bounds

    times                        = inst[Time]
    chams                        = inst[Chameleon]
    projections                  = times.map{Viz::Projection.new}
    nodes                        = chams.map{Viz::Node.new}
    # bounds[Viz::Projection]      = projections
    # bounds[Viz::Node]            = nodes
    bounds[Viz::Projection.over] = projections * inst[Time]
    bounds.hi[Viz::Node.atom]    = (nodes * inst[Chameleon]) ** projections

    puts "solving viz for prev chameleons..."
    viz_sol = @@timer.time_it {
      ChameleonsViz.solve :viz, bounds, n, Viz::Node => exactly(n-1)
    }
    t2 = @@timer.last_time
    puts "time: #{t2}"
    puts "total: #{t1 + t2}"

    unless n > 6
      projections.each do |p|
        nodes.product(nodes).each do |n1, n2|
          c1 = n1.atom.(p)
          c2 = n2.atom.(p)
          same_kind = c1.kind.(p.over) == c2.kind.(p.over)
          same_color = n1.color.(p) == n2.color.(p)
          assert_equal same_kind, same_color
        end
      end
    end
  end

  def bench_staged
    puts "warming up: solving viz chameleons no bounds, scope: 5"
    viz_sol = @@timer.time_it {
      ChameleonsViz.solve :viz, 5, Chameleon => exactly(5-1)
    }
    puts "time: #{@@timer.last_time}"

    n = 8
    puts "scope = #{n}"

    puts "solving viz chameleons no bounds..."
    viz_sol = @@timer.time_it {
      ChameleonsViz.solve :viz, n, Chameleon => exactly(n-1)
    }
    t0 = @@timer.last_time
    puts "time: #{t0}"

    puts "solving chameleons..."
    ch_sol = @@timer.time_it {
      Chameleons.solve :some_meet, n, Chameleon => exactly(n-1)
    }
    t1 = @@timer.last_time
    puts "time: #{t1}"
    assert ch_sol.satisfiable?

    inst = ch_sol.arby_instance
    bounds = inst.to_bounds

    projections = inst[Time].map{Viz::Projection.new}
    nodes       = inst[Chameleon].map{Viz::Node.new}
    bounds[Viz::Projection]      = projections
    bounds[Viz::Projection.over] = projections * inst[Time]
    bounds[Viz::Node]            = nodes
    bounds.hi[Viz::Node.atom]    = (nodes * inst[Chameleon]) ** projections

    puts "solving viz for prev chameleons..."
    viz_sol = @@timer.time_it {
      ChameleonsViz.solve :viz, bounds, n
    }
    t2 = @@timer.last_time
    puts "time: #{t2}"
    puts "total: #{t1 + t2}"

    puts "solving viz chameleons no bounds..."
    viz_sol = @@timer.time_it {
      ChameleonsViz.solve :viz, n, Chameleon => exactly(n-1)
    }
    t3 = @@timer.last_time
    puts "time: #{t3}"
  end

end
