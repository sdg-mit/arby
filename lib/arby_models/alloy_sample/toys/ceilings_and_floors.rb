require 'arby_models/alloy_sample/toys/__init'

module ArbyModels::AlloySample::Toys

  # =================================================================
  # In his 1973 song, Paul Simon said "One Man's Ceiling Is Another
  # Man's Floor".  Does it follow that "One Man's Floor Is Another
  # Man's Ceiling"?
  #
  # To see why not, check the assertion BelowToo.
  #
  # Perhaps simply preventing man's own floor from being his ceiling
  # is enough, as is done in the Geometry constraint.  BelowToo' shows
  # that there are still cases where Geometry holds but the
  # implication does not, although now the smallest solution has 3 Men
  # and 3 Platforms instead of just 2 of each.
  #
  # What if we instead prevent floors and ceilings from being shared,
  # as is done in the NoSharing constraint?  The assertion BelowToo''
  # has no counterexamples, demonstrating that the implication now
  # holds for all small examples.
  #
  # @original_author: Daniel Jackson (11/2001)
  # @modified_by:     Robert Seater (11/2004)
  # @translated_by:   Ido Efrati, Aleksandar Milicevic
  # =================================================================
  alloy :CeilingsAndFloors do

    sig Platform
    sig Man [ceiling, floor: Platform]

    fact paulSimon { all(m: Man) | some(n: Man) | n.above(m) }

    pred above[m, n: Man] { m.floor == n.ceiling }

    assertion belowToo { all(m: Man) | some(n: Man) | m.above(n) }
    check :belowToo, 2 # expect fail

    pred geometry { no(m: Man){ m.floor == m.ceiling }}

    assertion belowToo2 {
      if geometry
        all(m: Man) | some(n: Man) | m.above(n)
      end
    }

    check :belowToo2, 2 # expect pass
    check :belowToo2, 3 # expect fail

    pred noSharing {
      no(m,n: Man){ m != n && (m.floor == n.floor || m.ceiling == n.ceiling) }
    }

    assertion belowToo3 {
      if noSharing
        all(m: Man) | some(n: Man) | m.above(n)
      end
    }

    check :belowToo3, 6  # expect pass
    check :belowToo3, 10 # expect pass
  end
end
