require 'arby_models/alloy_sample/systems/__init'

module ArbyModels::AlloySample::Systems
  # =================================================================
  # A simple list module which demonstrates how to create predicates
  # and fields that mirror each other thus allowing recursive
  # constraints (even though recursive predicates are not currently
  # supported by Alloy)
  #
  # @author: Robert Seater
  # @translated_by: Aleksandar Milicevic
  # =================================================================
  alloy :Lists do

    sig Thing
    fact noStrayThings { Thing.in? List.(car) }

    abstract sig List [
      equivTo: (set List),
      prefixes: (set List)
    ]
    sig NonEmptyList extends List [
      car: (one Thing),
      cdr: (one List)
    ]
    sig EmptyList extends List

    pred isFinite[l: List] { some(e: EmptyList){ e.in? l.*cdr } }

    fact finite            { all(l: List) | isFinite[l] }

    fact equivalence {
      all(a, b: List) {
        a.in?(b.equivTo) <=> ((a.car == b.car and b.cdr.in? a.cdr.equivTo) and
                              (a.*cdr).size == (b.*cdr).size)
      }
    }

    assertion reflexive { all(l: List){ l.in? l.equivTo } }
    check :reflexive, 6 # expect pass

    assertion symmetric { all(a, b: List){ a.in?(b.equivTo) <=> b.in?(a.equivTo) } }
    check :symmetric, 6 # expect pass

    assertion empties   { all(a, b: EmptyList){ a.in? b.equivTo } }
    check :empties, 6  # expect pass

    fact prefix { # a is a prefix of b
      all(e: EmptyList, l: List){ e.in? l.prefixes } and
      all(a, b: NonEmptyList){ 
        (a.in? b.prefixes) <=> (a.car == b.car and a.cdr.in? b.cdr.prefixes and
                                (a.*cdr).size < (b.*cdr).size)
      }
    }

    pred show {
      some(a, b: NonEmptyList){ a != b and b.in? a.prefixes }
    }
    run :show, 4  # expect sat

  end
end
