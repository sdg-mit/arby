require 'arby_models/alloy_sample/toys/__init'

module ArbyModels::AlloySample::Toys

  # =================================================================
  # An Alloy model of the song "I Am My Own Grandpa" by Dwight
  # B. Latham and Moe Jaffe
  #
  # The challenge is to produce a man who is his own grandfather
  # without resorting to incest or time travel.  Executing the
  # predicate "ownGrandpa" will demonstrate how such a thing can
  # occur.
  #
  # The full song lyrics, which describe an isomorophic solution, are
  # included at the end of this file.
  #
  # @original_author: Daniel Jackson
  # @translated_by: Aleksandar Milicevic
  # =================================================================
  alloy :Grandpa do
    abstract sig Person [
      father: (lone Man),
      mother: (lone Woman)
    ]

    sig Man extends Person   [wife: (lone Woman)]
    sig Woman extends Person [husband: (lone Man)]

    fact biology     { no(p: Person) | p.in?(p.^(father+mother)) }
    fact terminology { wife == ~husband }

    fact socialConvention {
      no wife & (mother+father).rclosure.mother and
      no husband & (mother+father).rclosure.father
    }

    fun grandpas[p: Person][set Person] {
      let(parent: mother + father + father.wife + mother.husband) {
        p.(parent).(parent) & Man
      }
    }

    pred ownGrandpa[m: Man] { m.in? grandpas(m) }

    run :ownGrandpa, Person => 4 # expect sat

    fun parents[p: Person][set Person] {
      p.father + p.mother + p.father.wife + p.mother.husband
    }
  end
end
