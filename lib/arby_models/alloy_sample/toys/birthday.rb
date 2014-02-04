require 'arby_models/alloy_sample/toys/__init'

module ArbyModels::AlloySample::Toys
  # =================================================================
  # Birthday Book
  #
  # A classic Z example to explain the basic form of an Alloy
  # model. For the original, see J.M. Spivey, The Z Notation, Second
  # Edition, Prentice Hall, 1992.
  #
  # A birthday book has two fields: known, a set of names (of persons
  # whose birthdays are known), and date, a function from known names
  # to dates. The operation AddBirthday adds an association between a
  # name and a date; it uses the relational override operator (++), so
  # any existing mapping from the name to a date is
  # replaced. DelBirthday removes the entry for a given name.
  # FindBirthday obtains the date d for a name n. The argument d is
  # declared to be optional (that is, a singleton or empty set), so if
  # there is no entry for n, d will be empty. Remind gives the set of
  # names whose birthdays fall on a particular day.
  #
  # The assertion AddWorks says that if you add an entry, then look it
  # up, you get back what you just entered. DelIsUndo says that doing
  # DelBirthday after AddBirthday undoes it, as if the add had never
  # happened. The first of these assertions is valid; the second
  # isn't.
  #
  # The function BusyDay shows a case in which Remind produces more
  # than one card.
  #
  # @original_author: Daniel Jackson, 11/14/01
  # @translated_by:   Ido Efrati, Aleksandar Milicevic
  # =================================================================
  alloy :Birthday do
    sig Name
    sig Date
    sig BirthdayBook[
      known: (set Name),
      date: known ** (one Date)
    ]

    pred addBirthday [bb, bb1: BirthdayBook, n: Name, d: Date] {
      bb1.date == bb.date.merge(n ** d)
    }

    pred delBirthday[bb, bb1: BirthdayBook, n: Name] {
      bb1.date == bb.date - (n ** Date)
    }

    pred findBirthday[bb: BirthdayBook, n: Name, d: (lone Date)] {
      d == bb.date[n]
    }

    pred remind[bb: BirthdayBook, today: Date, cards: (set Name)] {
      cards == bb.date.(today)
    }

    pred initBirthdayBook [bb: BirthdayBook] {
      no bb.known
    }

    assertion addWorks {
      all(bb, bb1: BirthdayBook, n: Name, d: Date, d1: (lone Date)) |
        if addBirthday(bb, bb1, n, d) && findBirthday(bb1, n, d1)
          d == d1
        end
    }

    assertion delIsUndo {
      all(bb1, bb2, bb3: BirthdayBook, n: Name, d: Date) |
        if addBirthday(bb1, bb2, n, d) && delBirthday(bb2, bb3, n)
          bb1.date == bb3.date
        end
    }

    check :addWorks, 3, BirthdayBook => 2   # expect to hold
    check :delIsUndo, 3, BirthdayBook => 2  # expect to fail

    pred busyDay[bb: BirthdayBook, d: Date] {
      some(cards: (set Name)) {
        remind(bb, d, cards) && !lone(cards)
      }
    }

    run :busyDay, 3, BirthdayBook => 1 # expect sat
  end
end
