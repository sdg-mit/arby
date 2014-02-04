require 'arby/arby_dsl'
require 'arby/ast/bounds'

module ArbyModels
module ABZ14
  extend Arby::Dsl

  alloy :GraphModel do
    sig Node [val: (lone Int)]
    sig Edge [src, dst: (one Node)] {src != dst}
    sig Graph[nodes:(set Node), edges:(set Edge)]

    pred hampath[g: Graph, path: (seq Node)] {
      g.nodes.size == 2 and some g.edges and
      path[Int] == g.nodes and
      path.size == g.nodes.size and
      all(i: 0...path.size-1) |
      some(e: g.edges) {
        e.src == path[i] &&
        e.dst == path[i+1] }
    }
    assertion reach {
      all(g: Graph, path: (seq Node)) {
        g.nodes.in? path[0].*((~src).dst) if hampath(g, path)}
    }
    assertion uniq {
      all(g: Graph, path: (seq Node)) |
        if hampath(g, path)
          all(n: g.nodes) { path.(n).size == 1 }
        end
    }
    run :hampath, 5, Graph=>exactly(1), Node=>3
    check :reach, 5, Graph=>exactly(1), Node=>3
    check :uniq,  5, Graph=>exactly(1), Node=>3
  end

  class GraphModel::Graph
    def find_hampath
      bnds = Arby::Ast::Bounds.from_atoms(self)
      sol = GraphModel.solve :hampath, bnds
      if sol.satisfiable?
      then sol["$hampath_path"].project(1)
      else nil end
    end
  end

end
end
