require 'arby/arby_dsl'

module ArbyModels
  extend Arby::Dsl

  alloy :AddressBook do
    sig Name, Addr

    sig Book [
      addr: Name ** (lone Addr)
    ] do
      pred add[ans: Book, n: Name, a: Addr] {
        ans.addr == addr + n**a
      }

      pred del[ans: Book, n: Name] {
        ans.addr == addr - n**Addr
      }

      # fun do_add[n: Name, a: Addr][Book] {
      #   ans = Book.new
      #   ans.addr = addr + n**a
      #   ans
      # }

      # fun do_del[n: Name][Book] {
      #   ans = Book.new
      #   ans.addr = addr - n**a
      #   ans
      # }
    end

    assertion delUndoesAdd {
      all(b1, b2, b3: Book, n: Name, a: Addr) {
        if b1.addr[n].empty? && b1.add(b2, n, a) && b2.del(b3, n)
          b1.addr == b3.addr
        end
      }
    }

    assertion addIdempotent {
      all [:b1, :b2, :b3] => Book, n: Name, a: Addr do
        if b1.add(b2, n, a) && b2.add(b3, n, a)
          b2.addr == b3.addr
        end
      end
    }

    # assertion delUdoesAddF {
    #   all b1: Book, n: Name, a: Addr do
    #     b2 = b1.add(n, a)
    #     b3 = b2.del(n, a)
    #     b1 == b3
    #   end
    # }

    check :delUndoesAdd, "for 5 expect 0"
    check :addIdempotent, "for 5 expect 0"
  end

module AddressBook
  Expected_alloy = """
module AddressBook

sig Name  {}

sig Addr  {}

sig Book  {
  addr: Name -> lone Addr
}

pred add[self: Book, ans: Book, n: Name, a: Addr] {
  ans.addr = self.addr + n -> a
}

pred del[self: Book, ans: Book, n: Name] {
  ans.addr = self.addr - n -> Addr
}

assert delUndoesAdd {
  all b1: Book, b2: Book, b3: Book, n: Name, a: Addr {
    no b1.addr[n] && b1.add[b2, n, a] && b2.del[b3, n] => b1.addr = b3.addr
  }
}

assert addIdempotent {
  all b1: Book, b2: Book, b3: Book, n: Name, a: Addr {
    b1.add[b2, n, a] && b2.add[b3, n, a] => b2.addr = b3.addr
  }
}

check delUndoesAdd for 5 expect 0

check addIdempotent for 5 expect 0
"""
end

end
