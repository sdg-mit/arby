require 'arby/bridge/imports'
require 'arby/ast/instance'
require 'arby/ast/tuple_set'
require 'arby/ast/types'

module Arby
  module Bridge

    module Translator
      include Utils
      extend self

      # Takes an instance of Arby::Ast::Instance parametrized with
      # Arby::Bridge::Atom, and Arby::Bridge::TupleSet, and converts
      # it to an instance of the same class parametrized with
      # Arby::Ast::Sig, and Arby::Ast::TupleSet.  Additionally, it
      # populates the field values of the newly created atoms
      # according to field values in +inst+.
      #
      # @param inst [Arby::Ast::Instance<Arby::Bridge::Atom, Arby::Bridge::TupleSet>]
      # @param univ [Arby::Ast::Universe]
      # @return [Arby::Ast::Instance<Arby::Ast::Sig, Arby::Ast::TupleSet>]
      def to_arby_instance(inst, univ=nil, model=nil)
        model ||= Arby.meta

        atoms   = inst.atoms.map{|a| _get_atom(model, a, univ)}.compact
        tmpi    = Arby::Ast::Instance.new :atoms => atoms, :univ => univ

        flds = model.reachable_sigs.map{|s| s.meta.fields}.flatten.map{ |fld|
          fld_name = Arby.conf.alloy_printer.arg_namer[fld]
          ts = inst.field(fld_name) and [fld, _to_tuple_set(model, tmpi, ts)]
        }
        skolems = inst.skolems.map{|name|
          [name, _to_tuple_set(model, tmpi, inst.skolem(name))]
        }

        fld_map    = Hash[flds.compact]
        skolem_map = Hash[skolems.compact]

        # restore field values
        atoms.select{|a| a.is_a?(Arby::Ast::ASig)}.each do |atom|
          atom.meta.pfields(false).each do |fld|
            # select those tuples in +fld+s relation that have +atom+ on the lhs
            fld_tuples = fld_map[fld].select{|tuple| tuple[0] == atom}
            # strip the lhs
            fld_val = fld_tuples.map{|tuple| tuple[1..-1]}
            # write that field value
            atom.write_field(fld, fld_val)
          end
        end

        Arby::Ast::Instance.new :atoms      => atoms,
                                :fld_map    => fld_map,
                                :skolem_map => skolem_map,
                                :dup        => false,
                                :univ       => univ,
                                :model      => model
      end

      private

      SIG_PREFIX = "this/"

      def _get_atom(model, atom, univ=nil)
        new_atom =
          (univ and univ.find_atom(atom.label)) ||
          (sig_cls = _this_type_to_sig!(model, atom.type) and sig_cls.new())
        if new_atom
          new_atom.__label = atom.label
          new_atom
        else
          atom
        end
      end

      def _type_to_atype(model, type)
        Arby::Ast::AType.get type.prim_sigs.map{ |a4prim_sig|
          prim_sig_name = a4prim_sig.toString
          sig_cls = _type_to_sig(model, nil, prim_sig_name)
          (sig_cls ? sig_cls : Arby::Ast::AType.builtin(prim_sig_name)) or break nil
        }, false
      end

      def _type_to_sig(model, type, type_name=nil)
        return nil if type and type.arity != 1
        sig_name = type ? type.signature : type_name
        sig_name = sig_name[SIG_PREFIX.size..-1] if sig_name.start_with?(SIG_PREFIX)
        model.reachable_sigs.find{|s| Arby.conf.alloy_printer.sig_namer[s] == sig_name}
        # Arby.meta.find_sig(sig_name)
      end

      def _type_to_atype!(*a) _type_to_atype(*a) or fail "type #{type} not found" end
      def _type_to_sig!(*a)   _type_to_sig(*a) or fail "sig #{type} not found" end
      def _this_type_to_sig!(model, type)
        if type.signature.start_with?(SIG_PREFIX)
          _type_to_sig!(model, type)
        else
          _type_to_sig(model, type)
        end
      end

      # @param inst [Arby::Ast::Instance<Arby::Ast::Sig, Arby::Ast::TupleSet>]
      # @param ts [Arby::Bridge::TupleSet]
      def _to_tuple_set(model, inst, ts)
        tuples = ts.tuples.map do |tuple|
          atoms = tuple.map{|a| inst.atom!(a.label)}
        end
        type = _type_to_atype!(model, ts.type)
        Arby::Ast::TupleSet.wrap(tuples, type)
      end

    end
  end
end
