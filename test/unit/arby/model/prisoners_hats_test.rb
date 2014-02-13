require 'my_test_helper'
require 'arby_models/prisoners_hats'
require 'arby/helpers/test/dsl_helpers'
require 'arby/initializer.rb'
require 'arby/bridge/compiler'
require 'arby/bridge/solution'

class PrisonersHatsTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  include ArbyModels::PrisonersHats

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(ArbyModels::PrisonersHats)
  end

  def test_als
    # puts ArbyModels::PrisonersHats.to_als
    assert ArbyModels::PrisonersHats.compile
  end

  def _test_s1 # broken
    pr = 4.times.map{Prisoner.new}
    bnds = Arby::Ast::Bounds.new
    bnds[Prisoner] = pr
    bnds[Prisoner::first] = pr.first
    bnds[Prisoner::next] = (0...pr.size-1).map{|i| [pr[i],  pr[i+1]]}


    sol = ArbyModels::PrisonersHats.solve :allAmbig, 4, bnds
    round = 0
    while true
      round += 1; solvable = []; rsol = sol
      puts "====================== round #{round}"

      while rsol.satisfiable?
        puts "ambiguos: #{rsol[Prisoner::hatColor]}"
        rsol = rsol.next { Prisoner::hatColor != inst[Prisoner::hatColor] }
      end
      rsol = rsol.model.solve :allAmbigExcept, 4, bnds
      while rsol.satisfiable?
        certain = rsol['$allAmbigExcept_certain']
        colors = rsol[Prisoner::hatColor]
        solvable << colors
        puts "#{colors} -> #{certain} deduced his hat color: #{certain.deduced1[certain]}"
        rsol = rsol.next { Prisoner::hatColor != inst[Prisoner::hatColor] }
      end

      break if solvable.empty?

      sol = sol.next(:solvable => solvable) do
        solvable.map{|hc|
          (hatColor != hc) &&
          all(p: Prisoner){ p.deduced1 != hc && p.deduced2 != hc}
        }.arby_join(Arby::Ast::Ops::AND)
      end
    end

  end
end




