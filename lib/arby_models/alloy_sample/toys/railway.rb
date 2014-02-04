require 'arby_models/alloy_sample/toys/__init'

module ArbyModels::AlloySample::Toys
  # =================================================================
  # A simple model of a railway system. Trains sit on segments of tracks
  # and segments overlap one another. It shows a that simple gate policy
  # does not ensure train safety.
  #
  # @original_author: Daniel Jackson
  # @translated_by:   Ido Efrati, Aleksandar Milicevic
  # =================================================================
  alloy :Railway do

    sig Seg [ :next, overlaps: (set Seg) ]
    fact { all(s: Seg) | s.in?(s.overlaps) }
    fact { all(s1, s2: Seg) | if s1.in? s2.overlaps then s2.in? s1.overlaps end }

    sig Train
    sig GateState  [ closed: (set Seg) ]
    sig TrainState [ on: Train ** (lone Seg), occupied: (set Seg) ]
    fact {
      all(x: TrainState) {
        x.occupied == Seg.select{|s| some(t: Train){ t.(x.on) == s }}
      }
    }

    pred safe[x: TrainState] {
      all(s: Seg) { lone s.overlaps.~(x.on) }
    }

    pred mayMove[g: GateState, x: TrainState, ts: (set Train)] {
      no ts.(x.on) & g.closed
    }

    pred trainsMove[x, x1: TrainState, ts: (set Train)] {
      all(t: ts)         { t.(x1.on).in? t.(x.on).next } and
      all(t: Train - ts) { t.(x1.on) == t.(x.on) }
    }

    pred gatePolicy[g: GateState, x: TrainState] {
      x.occupied.overlaps.~(Seg::next).in? g.closed and
      all(s1, s2: Seg) |
        if some s1.next.overlaps & s2.next
          lone (s1+s2) - g.closed
        end
    }

    assertion policyWorks {
      all(x, x1: TrainState, g: GateState, ts: (set Train)) |
        if mayMove(g, x, ts) && trainsMove(x, x1, ts) && safe(x) && gatePolicy(g, x)
          safe(x1)
        end
    }

    check :policyWorks, Train => 2, GateState => 1, TrainState => 2, Seg => 4 # expect fail

    pred trainsMoveLegal[x, x1: TrainState, g: GateState, ts: (set Train)] {
      trainsMove(x, x1, ts) and
      mayMove(g, x, ts) and
      gatePolicy(g, x)
    }

    run :trainsMoveLegal, 3 # expect sat

    ## helpful for getting good visualization.
    fun contains[][TrainState ** Seg ** Train] {
      (TrainState ** Seg ** Train).select{|state, seg, train| seg == train.(state.on)}
    }

  end
end
