require 'arby/arby_dsl'

# Arby.conf.sym_exe.convert_missing_fields_to_joins = true

module ArbyModels
module ChameleonExample
  extend Arby::Dsl

  alloy :Viz do
    enum Color(Red, Blue, Green, Grey)
    enum Shape(Box, Circle, Triangle)

    ordered sig Projection [ over: univ ]

    sig Node [
      node:  (set Projection),
      color: (Color one ** node),
      shape: (Shape one ** node),
      atom:  (univ  one ** node)
    ]

    sig Edge [
      edge:   (set Projection),
      source: (Node one ** edge),
      dest:   (Node one ** edge)
    ]

    fact {
      all(p: Projection) | all(e: edge.(p)) {
        e.(source + dest).(p).in? node.(p)
      }
    }
  end

  alloy :Chameleons do
    ordered sig Time

    enum Kind(R, G, B)

    sig Chameleon [
      kind: (Kind one ** Time),
      meets: (Chameleon lone ** Time)
    ]

    pred change[t1, t2: Time, c: Chameleon] {
      cmeets = c.meets.(t1)

      some c.meets.(t1) and
      c.kind.(t1) != cmeets.kind.(t1) and
      c.kind.(t2) == Kind - (c + cmeets).kind.(t1)
    }

    pred same[t1, t2: Time, c: Chameleon] {
      (no c.meets.(t1) or
       c.kind.(t1) == c.meets.(t1).kind.(t1)) and
      c.kind.(t2) == c.kind.(t1)
    }

    fact inv {
      all(t: Time) { meets.(t) == ~meets.(t) and no iden & meets.(t) }
    }

    fact changes {
      all(t1: Time) | all(t2: t1.next, c: Chameleon) {
        change(t1, t2, c) or same(t1, t2, c)
      }
    }

    pred some_meet { some meets }
    run :some_meet
  end

  alloy :ChameleonsViz do
    open Viz, Chameleons

    pred theme {
      # same ordering of Time and Projection
      Projection::next == over.(Time::next).(~over) and

      # project over Time
      over.in? (Projection ** (one_one Time)) and

      all(t: Time) | let(p: over.(t)) {
        atom.(p).in? (node.(p) ** (one_one Chameleon)) and

        # Viz edges correspond to meets
        meets.(t) == (~source.(p).atom.(p)).dest.(p).atom.(p) and

        all(c: Chameleon) {
          # Viz shape is Box iff it doesn't meet anyone
          (no c.meets.(t)) <=> (atom.(p).(c).shape.(p) == Box) and

          # for every other chameleon
          all(c2: Chameleon - c) {
            # Viz colors are the same iff their colors are the same
            (c.kind.(t) == c2.kind.(t)) <=>
            (atom.(p).(c).color.(p) == atom.(p).(c2).color.(p)) and

            # Viz shapes are the same for those who meet
            if c.in? c2.meets.(t)
              atom.(p).(c).shape.(p) == atom.(p).(c2).shape.(p)
            end
          }
        }
      } and

      # stability over Time: same colored Chameleons -> same viz colors
      all(t, t2: Time) | all(c, c2: Chameleon) | let(p: over.(t), p2: over.(t2)) {
          if t != t2 and c.kind.(t) == c2.kind.(t2)
            atom.(p).(c).color.(p) == atom.(p2).(c2).color.(p2)
          end
        }
    }

    pred viz { some_meet and theme }
    run :viz, 5, Chameleon => (exactly 4)
  end

end
end
