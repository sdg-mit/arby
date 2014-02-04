require 'arby_models/alloy_sample/systems/__init'
require 'arby_models/alloy_sample/util/relation'

module ArbyModels::AlloySample::Systems
  # ==============================================================
  # Model of the Java type system. The TypeSoundness assertion claims
  # that if a Java program type checks successfully, then a field will
  # cannot be assigned an incorrect type.
  #
  # @author: Daniel Jackson
  # @translated_by: Aleksandar Milicevic
  # ==============================================================
  alloy :JavatypesSoundness do
    open ArbyModels::AlloySample::Util::Relation

    abstract sig Type [
      xtends: (set Type)
    ]
    sig Interface extends Type {
      xtends.in? Interface
    }
    sig Class extends Type [
      implements: (set Interface),
      fields: (set Field)
    ] {
      lone xtends and xtends.in? Class
    }

    sig Field [
      declType: Type
    ]

    fact { acyclic(xtends, Type) }

    sig Slot

    abstract sig Value
    one sig Null extends Value
    sig Object extends Value [
      type: Class,
      slot: Field ** (lone_lone Slot)
    ] {
      slot.(Slot) == type.fields
    }

    abstract sig Statement
    sig Assignment extends Statement [ var: Variable, expr: Expr ]
    sig Setter extends Statement     [ lexpr, rexpr: Expr, field: Field ]

    abstract sig Expr [
      type: Type,
      subexprs: (set Expr)
    ] {
      subexprs == this + this.^(Assignment::expr)
    }
    sig Variable extends Expr    [ declType: Type ] { type == declType }
    sig Constructor extends Expr [ class: Class ]
    sig Getter extends Expr      [ field: Field, expr: Expr ] { type == field.declType }

    sig State [
      objects: (set Object),
      reaches: Object ** Object,
      vars: (set Variable),
      holds: ((Slot + Variable) ** (lone Value)),
      val: Expr ** (lone Value)
    ] {
      all(o: Object){ o.(reaches) == holds[o.slot[Field]] & Object } and
      holds.(Value) & Variable == vars and
      objects == holds[vars].^(reaches) and
      all(e: Expr) | let(v: val[e]) {
        (if e.in? Variable    then v == holds[e] end) and
        (if e.in? Getter      then v == holds[(val[e.expr]).slot[e.field]] end) and
        (if e.in? Constructor then v.in?(Object) and v.type == e.type end)
      }
    }

    pred runtimeTypesOK[s: State] {
      all(o: s.objects) | all(f: o.type.fields) |
        let(v: s.holds[o.slot[f]]) { hasType(v, f.declType) } and
      all(var: s.vars) |
        let(v: s.holds[var]){ hasType(v, var.declType) }
    }

    pred hasType[v: Value, t: Type] {
      v.in? Null or subtype(v.type, t)
    }

    pred subtype[t, t_: Type] {
      if t.in? Class
        let(supers: (t & Class).*(Class.<xtends)) {
          t_.in? supers + supers.implements.*(Interface.<xtends)
        }
      elsif t.in? Interface
        t_.in? (t & Interface).*(Interface.<xtends)
      end
    }

    pred typeChecksSetter[stmt: Setter] {
      all(g: (Getter & stmt.(lexpr+rexpr).subexprs)){ g.field.in? g.expr.type.fields }and
      stmt.field.in? stmt.lexpr.type.fields and
      subtype(stmt.rexpr.type, stmt.field.declType)
    }

    pred executeSetter[s, s_: State, stmt: Setter] {
      (stmt.(rexpr+lexpr).subexprs & Variable).in? s.vars and
      s_.objects == s.objects and s_.vars == s.vars and
      let(rval: s.val[stmt.rexpr], lval: s.val[stmt.lexpr]) {
        no lval & Null and
        s_.holds == s.holds.merge(lval.slot[stmt.field] ** rval)
      }
    }

    assertion typeSoundness {
      all(s, s_: State, stmt: Setter) |
        if runtimeTypesOK(s) && executeSetter(s, s_, stmt) && typeChecksSetter(stmt)
          runtimeTypesOK[s_]
        end
    }

    fact { all(o, o_: Object){ o == o_ if some o.slot[Field] & o_.slot[Field] } }
    fact { all(g: Getter){ no g & g.^(subexprs) } }

    fact scopeFact {
      Assignment.size <= 1 && Class.size <= 5 && Interface.size <= 5
    }

    check :typeSoundness, 3 # expect pass

    check :typeSoundness, State => 2, Assignment => 1,
                          Statement => 1, Interface => 5, Class => 5, Null => 1,
                          Object => 7,  Expr => 12, Field => 3, Slot => 3 # expect pass
  end
end
