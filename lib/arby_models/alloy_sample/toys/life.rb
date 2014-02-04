require 'arby_models/alloy_sample/toys/__init'

module ArbyModels::AlloySample::Toys
  # =================================================================
  # John Conway's Game of Life
  #
  #  For a detailed description, see:
  #   http://www.math.com/students/wonders/life/life.html
  #
  # @authors:       Bill Thies, Manu Sridharan
  # @translated_by: Aleksandar Milicevic
  # =================================================================
  alloy :Life do

    sig Point[right, below: (lone Point)]
    ordered sig State[live: (set Point)]

    fact acyclic {
      all(p: Point){ p.not_in? p.^(right + below) }
    }

    one sig Root extends Point

    fact innerSquaresCommute {
      all(p: Point) {
        p.below.right == p.right.below and
        if some p.below and some p.right then some p.below.right end
      }
    }

    fact topRow {
      all(p: Point-Root){ if no p.~below then (p.*below).size == (Root.*below).size end }
    }

    fact connected {
      Root.*(right + below) == Point
    }

    pred square {
      (Root.*right).size == (Root.*below).size
    }

    run :square, Point => 6, State => 3 # expect sat

    pred rectangle {}

    fun neighbors[p: Point][set Point] {
      p.right + p.right.below + p.below +
      p.below.(~right) + p.(~right) +
      p.(~right).(~below) + p.(~below) +
      p.(~below).right
    }

    fun liveNeighborsInState[p: Point, s: State][set Point] {
      neighbors(p) & s.live
    }

    pred trans[pre, post: State, p: Point] {
      let(preLive: liveNeighborsInState(p,pre)) {
        # dead cell w/ 3 live neighbors becomes live
        if p.not_in? pre.live and preLive.size == 3
          p.in? post.live
        elsif p.in? pre.live and preLive.size.in?([2, 3])
          # live cell w/ 2 or 3 live neighbors stays alive
          p.in? post.live
        else
          p.not_in? post.live
        end
      }
    }

    # fact validTrans {
    #   all(pre: State - State::last) |
    #     let(post: State::next[pre]) |
    #       all(p: Point) |
    #         trans(pre, post, p)
    # }

    fact validTrans {
      all(pre: State - State::last) {
        let(post: State::next[pre]) {
          all(p: Point) {
            trans(pre, post, p)
          }
        }
      }
    }


    pred show {}

    # slow
    run :show, Point => exactly(12), State => 3 # expect sat

    # a small but interesting example
    pred interesting {
      some State.(live) and
      some Point - State.(live) and
      some right and
      some below
    }

    run :interesting, Point => exactly(6), State => 3 # expect 1
  end
end
