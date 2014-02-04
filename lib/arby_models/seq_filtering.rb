require 'arby/arby_dsl'

# Arby.conf.sym_exe.convert_missing_fields_to_joins = true

module ArbyModels
  extend Arby::Dsl

  alloy_model :SeqFiltering do
    sig A [
      x: Int[2..3]
    ]

    fun prevOccurrences[s: (seq A), idx: Int][set Int] {
      s.indsOf(s[idx]).select{|i| i < idx}
    }

    pred filter[s: (seq A), ans: (seq A)] {
      filtered = s[Int].select{|a| a.x < 3}
      s.size == 4 and
      ans[Int] == filtered and
      all(a: filtered) { ans.join(a).size == s.join(a).size } and
      all(i1, i2: s.inds) {
        if i2 > i1 && filtered.contains?(s[i1] + s[i2])
          some(ii1, ii2: ans.inds) {
            ii2 > ii1 and
            ans[ii1] == s[i1] and
            ans[ii2] == s[i2] and
            prevOccurrences(s, i1) == prevOccurrences(ans, ii1) and
            prevOccurrences(s, i2) == prevOccurrences(ans, ii2)
          }
        end
      }
    }

    procedure filter_i[s: (seq A)][seq A] do
      # s.select{|a| a.x < 3}
      idx = 0
      ans = []
      while idx < s.size
        ans << s[idx] if s[idx].x < 3
        idx += 1
      end
      ans
    end

    run :filter, "for 4"
  end
end
