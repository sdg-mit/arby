require 'arby/arby_dsl'

module ArbyModels
  extend Arby::Dsl

  alloy :PrisonersHats do

    # abstract sig Color
    # one sig Red extends Color
    # one sig Blue extends Color
    enum Color(Red, Blue)

    ordered sig Prisoner [
      hatColor: Color,
      deduced1: Prisoner ** (one Color),
      deduced2: Prisoner ** (one Color)
    ] {
      # deduction_rule(this, this.deduced1) and
      # deduction_rule(this, this.deduced2)
      # colors_fact(this.deduced1) and
      # colors_fact(this.deduced2) and
      # (this.sees.< Prisoner::hatColor).in? this.deduced1 and
      # (this.sees.< Prisoner::hatColor).in? this.deduced2
      # all(p: this.sees){
      #   this.deduced1[p] == p.hatColor &&
      #   this.deduced2[p] == p.hatColor
      # }
    }

    pred colors_fact[rel: Prisoner ** Color] {
      rel.(Red).size == 2 && rel.(Blue).size == 2
    }
    pred deduction_rule[p: Prisoner, rel: Prisoner ** Color] {
      colors_fact(rel) and (sees(p).< hatColor).in? rel
    }

    fun sees[p: Prisoner][set Prisoner] {
      p.nexts - Prisoner::last
    }

    fact hatColors {
      colors_fact(hatColor) and
      all(p: Prisoner) { deduction_rule(p, p.deduced1) && deduction_rule(p, p.deduced2) }
    }

    pred allAmbig {
      all(p: Prisoner){ p.deduced1[p] != p.deduced2[p] }
    }

    pred allAmbigExcept[certain: Prisoner] {
      all(p: Prisoner - certain){ p.deduced1[p] != p.deduced2[p] }
    }

    # # for visualization only
    # fun isRed[][Prisoner] {Prisoner.select{|p| p.hatColor == Red}}
    # fun isBlu[][Prisoner] {Prisoner.select{|p| p.hatColor == Blue}}
    # fun deducedBlu[][Prisoner ** Prisoner] {
    #   (Prisoner**Prisoner).select{|p1, p2| p1.deduced[p2] == Blue}}
    # fun deducedRed[][Prisoner ** Prisoner] {
    #   (Prisoner**Prisoner).select{|p1, p2| p1.deduced[p2] == Red}}
    # fun ambiguous[][Prisoner ** Prisoner]  {
    #   (Prisoner**Prisoner).select{|p1, p2| p1.deduced[p2].size != 1}}
  end
end
