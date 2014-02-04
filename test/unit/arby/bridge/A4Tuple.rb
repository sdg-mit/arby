
Rjb::load('/Users/potter/MIT/4thyear/Fall2013/6uap/alloy/dist/alloy4.2_2013-11-02.jar', ['-Xmx512m', '-Xms256m'])

Type_RJB = Rjb::import('edu.mit.csail.sdg.alloy4compiler.ast.Type')
SigPrimSig_RJB = Rjb::import('edu.mit.csail.sdg.alloy4compiler.ast.Sig$PrimSig')
Tuple_RJB = Rjb::import('kodkod.instance.Tuple')
A4Solution_RJB = Rjb::import('edu.mit.csail.sdg.alloy4compiler.translator.A4Solution')

class A4Tuple
	tuple = Tuple_RJB
	sol = A4Solution_RJB

	def initialize(tuple, sol)
		@tuple = tuple
		@sol = sol
	end

	def arity()
		return @tuple.arity
	end

	def atom(i)
		return @sol.atom2name(@tuple.atom(i))
	end
	
	def sig(i) 
		return @sol.atom2sig(@tuple.atom(i))
	end 

	def type()
    	ans = nil
    	arityValue = arity()
    	for i in 0...arityValue
    		if ans == nil
    			ans = sig(0).type
    		else
    			ans=ans.product(sig(i).type())
    		end
    	end    
    	return ans
    end

 
	def each()
		for i in 0...(arity())
            yield @tuple.atom(i)
        end
	end
end



# class Comparable
#   def initialize(val)
#     @value = val
#   end
#   def compareTo(oponent)
#     return @value - oponent.to_i
#   end
# end
# cp = Comparable.new(3)
# cp = Rjb::bind(cp, 'java.lang.Comparable')
# bind(obj, name)
# bind ruby object and Java interface
# obj
# ruby object
# name
# Java's interface name
# return
# new object that's bound to the specified interface


