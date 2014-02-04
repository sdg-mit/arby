require 'arby_models/alloy_sample/systems/__init'

module ArbyModels::AlloySample::Systems
  # =================================================================
  # Model of mark and sweep garbage collection.
  #
  # @translated_by: Aleksandar Milicevic
  # =================================================================
  alloy :MarkSweep do
    # a node in the heap
    sig Node

    sig HeapState [
      left, right: Node ** (lone Node),
      marked: (set Node),
      freeList: (lone Node)
    ]

    pred clearMarks[hs, hs_: HeapState] {
      # clear marked set
      no hs_.marked and
      # left and right fields are unchanged
      hs_.left == hs.left and
      hs_.right == hs.right
    }

    # simulate the recursion of the mark() function using transitive closure
    fun reachable[hs: HeapState, n: Node][set Node] {
      n + n.^(hs.left + hs.right)
    }

    pred mark[hs: HeapState, from: Node, hs_: HeapState] {
      hs_.marked == hs.reachable(from) and
      hs_.left == hs.left and
      hs_.right == hs.right
    }

    # complete hack to simulate behavior of code to set freeList
    pred setFreeList[hs, hs_: HeapState] {
      # especially hackish
      hs_.freeList.*(hs_.left).in?(Node - hs.marked) and
      all(n: Node) {
        if n.not_in? hs.marked
          no hs_.right[n] and
          hs_.left[n].in? hs_.freeList.*(hs_.left) and
          n.in? hs_.freeList.*(hs_.left)
        else
          hs_.left[n] == hs.left[n] and
            hs_.right[n] == hs.right[n]
        end
      } and
      hs_.marked == hs.marked
    }

    pred gc[hs: HeapState, root: Node, hs_: HeapState] {
      some(hs1, hs2: HeapState) {
        hs.clearMarks(hs1) && hs1.mark(root, hs2) && hs2.setFreeList(hs_)
      }
    }

    assertion soundness1 {
      all(h, h_: HeapState, root: Node) |
        if h.gc(root, h_)
          all(live: h.reachable(root)) {
            h_.left[live] == h.left[live] and
            h_.right[live] == h.right[live]
          }
        end
    }

    assertion soundness2 {
      all(h, h_: HeapState, root: Node) |
        if h.gc(root, h_)
          no h_.reachable(root) & h_.reachable(h_.freeList)
        end
    }

    assertion completeness {
      all(h, h_: HeapState, root: Node) |
        if h.gc(root, h_)
          (Node - h_.reachable(root)).in? h_.reachable(h_.freeList)
        end
    }

    check :soundness1, 5 # expect pass
    check :soundness2, 5 # expect pass
    check :completeness, 5 # expect pass
  end
end
