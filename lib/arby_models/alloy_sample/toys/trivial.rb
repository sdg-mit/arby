require 'arby_models/alloy_sample/toys/__init'

module ArbyModels::AlloySample::Toys

  # =================================================================
  # a trivial model whose command has no solution
  alloy :Trivial do
    sig S

    fact { Int(1) == 2 }

    run { some S } # expect unsat
  end

end
