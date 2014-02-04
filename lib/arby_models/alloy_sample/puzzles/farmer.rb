require 'arby_models/alloy_sample/puzzles/__init'

module ArbyModels::AlloySample::Puzzles

  alloy :FarmerModel do
    # ================================================================
    # The classic river crossing puzzle. A farmer is carrying a fox, a
    # chicken, and a sack of grain. He must cross a river using a boat
    # that can only hold the farmer and at most one other thing. If
    # the farmer leaves the fox alone with the chicken, the fox will
    # eat the chicken; and if he leaves the chicken alone with the
    # grain, the chicken will eat the grain. How can the farmer bring
    # everything to the far side of the river intact?
    #
    # @authors: Greg Dennis, Rob Seater
    # @translated_by: Aleksandar Milicevic
    #
    # Acknowledgements to Derek Rayside and his students for finding and
    # fixing a bug in the "crossRiver" predicate.
    # ================================================================


    # The farmer and all his possessions will be represented as Objects.
    # Some objects eat other objects when the Farmer's not around.
    abstract sig Object [eats: (set Object)]
    one sig Farmer, Fox, Chicken, Grain < Object

    # Define what eats what when the Farmer' not around.
    # Fox eats the chicken and the chicken eats the grain.

    fact eating { eats == Fox ** Chicken + Chicken ** Grain }

    # The near and far relations contain the objects held on each
    # side of the river in a given state, respectively.

    ordered sig State [
      near: (set Object),
      far: (set Object)
    ]

    # In the initial state, all objects are on the near side.
    fact initialState {
      let(s0: State::first) {
        s0.near == Object and no s0.far
      }
    }

    # Constrains at most one item to move from 'from' to 'to'.
    # Also constrains which objects get eaten.
    pred crossRiver[from, from_, to, to_: (set Object)] {
      # either the Farmer takes no items
      (from_ == from - Farmer - from_.eats and
       to_ == to + Farmer) or
      # or the Farmer takes one item
      one(x: from - Farmer) {
        from_ == from - Farmer - x - from_.eats and
        to_ == to + Farmer + x
      }
    }

    # crossRiver transitions between states
    fact stateTransition {
      all(s: State) | all(s_: State::next[s]) |
        if Farmer.in? s.near
          crossRiver(s.near, s_.near, s.far, s_.far)
        else
          crossRiver(s.far, s_.far, s.near, s_.near)
        end
    }

    # the farmer moves everything to the far side of the river.
    pred solvePuzzle { State::last.far == Object }
    run :solvePuzzle, State => 8 # expect sat

    # no Object can be in two places at once
    # this is implied by both definitions of crossRiver
    assertion noQuantumObjects {
      no(s: State) | some(x: Object) { x.in? s.near and x.in? s.far }
    }
    check :noQuantumObjects, State => 8 # expect pass

  end
end
