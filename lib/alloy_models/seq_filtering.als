module SeqFiltering
open util/ordering[Time]

sig A  {
  x: Int
} {
}

fun prevOccurrences[s: seq A, idx: Int]: set Int {
  {i: s.indsOf[s[idx]] | i < idx}
}

pred filter[s: seq A, ans: seq A] {
  ans.elems = ({a: s.elems | a.x < 3})
  all a: {a: s.elems | a.x < 3} {
    #ans.a = #s.a
  }
  all i1: s.inds, i2: s.inds {
    i2 > i1 && s[i1] + s[i2] in ({a: s.elems | a.x < 3}) => (some ii1: ans.inds, ii2: ans.inds {
      ii2 > ii1
      ans[ii1] = s[i1]
      ans[ii2] = s[i2]
      prevOccurrences[s, i1] = prevOccurrences[ans, ii1]
      prevOccurrences[s, i2] = prevOccurrences[ans, ii2]
    }
    )
  }
}


sig Time{}
one sig State {
  _s: (seq A) -> Time,
  _ans: (seq A) -> Time
}

pred filteri[s: seq A, ans: seq A] {
  State._s.first = s
  no State._ans.first
  all t: Time - last {
    State._s.(t.next) = State._s.t
    let idx = #t.prevs, t' = t.next |
      (idx < #State._s.t && (State._s.t)[idx].x < 3) => {
        add[State._ans.t, (State._s.t)[idx]] = State._ans.t'
      } else {
        State._ans.t' = State._ans.t
      }
  }
  ans = State._ans.last
}

check {
  all s, ans, ansi: seq A | (filter[s, ans] && filteri[s, ansi]) => ans = ansi
} for 5 but 6 Time

run filteri for 6 but 7 Time

run filter for 4 
