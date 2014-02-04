require 'arby/ast/field'
require 'arby/ast/fun'
require 'sdg_utils/caching/searchable_attr'
require 'weakref'

module Arby
  module Ast

    # ----------------------------------------------------------------------
    # Holds meta information (e.g., fields and their types) about
    # a sig class.
    #
    # @attr sig_cls    [Class <= Sig]
    # @attr subsigs    [Array(Class <= Sig)]
    # @attr fields     [Array(Field)]
    # @attr inv_fields [Array(Field)]
    # ----------------------------------------------------------------------
    class SigMeta
      include SDGUtils::Caching::SearchableAttr

      attr_reader :sig_cls, :parent_sig
      attr_reader :multiplicity, :placeholder
      attr_reader :extra

      attr_hier_searchable :subsig, :field, :inv_field, :fun, :pred, :fact, :procedure

      def initialize(sig_cls, placeholder=false, abstract=false)
        @sig_cls      = sig_cls
        @parent_sig   = sig_cls.superclass if (sig_cls.superclass.is_sig? rescue nil)
        @placeholder  = placeholder
        @extra        = {}
        @atoms        = []
        set_abstract if abstract
        init_searchable_attrs(SigMeta)
      end

      def unregister_atom(atom) @atoms.delete(WeakRef.new(atom)) end
      def register_atom(atom)
        unless atom.registered?
          @atoms << WeakRef.new(atom)
          atom.set_registered
        end
      end
      def register_atoms(atoms)
        if ASig === atoms
          register_atom(atoms)
        else
          atoms.each(&method(:register_atom))
        end
      end
      def atoms
        alive_refs = @atoms.select(&:weakref_alive?)
        @atoms = alive_refs
        alive_refs.map(&:__getobj__)
      end

      def all_funs()        funs + preds end
      def any_fun(name)     all_funs.find{|f| f.name.to_s == name.to_s} end

      def _hierarchy_up()   parent_sig && parent_sig.meta end

      def abstract?()       @multiplicity == :abstract end
      def one?()            @multiplicity == :one end
      def lone?()           @multiplicity == :lone end
      def placeholder?()    @placeholder end
      def enum?()           !!@enum end
      def enum_const?()     parent_sig && parent_sig.meta.enum? end
      def ordered?()        !!@ordered end
      def atom?()           !!@atom end
      def atom_id()         @atom end

      def set_abstract()    @multiplicity = :abstract end
      def set_one()         @multiplicity = :one end
      def set_lone()        @multiplicity = :lone end
      def set_placeholder() set_abstract; @placeholder = true end
      def set_enum()        @enum = true end
      def set_ordered()     @ordered = true end
      def set_atom(id)      set_one; @atom = id end

      def persistent_fields(*args)
        fields(*args).select { |f| f.persistent? }
      end

      def transient_fields(*args)
        fields(*args).select { |f| f.transient? }
      end

      alias_method :pfields, :persistent_fields
      alias_method :tfields, :transient_fields

      def all_fields(include_inherited=false)
        fields(include_inherited) + inv_fields(include_inherited)
      end

      def any_field(name, include_inherited=false)
        field(name, include_inherited) || inv_field(name, include_inherited)
      end

      def sigs_including_sub_and_super
        all_supersigs + [sig_cls] + all_subsigs
      end

      def fields_including_sub_and_super
        sigs_including_sub_and_super.map(&:meta).map(&:fields).flatten
      end

      def inv_fields_including_sub_and_super
        sigs_including_sub_and_super.map(&:meta).map(&:inv_fields).flatten
      end

      def all_subsigs
        @subsigs.map{|s| [s] << s.all_subsigs}.flatten
      end

      def all_supersigs
        if parent_sig
          [parent_sig] + parent_sig.meta.all_supersigs
        else
          []
        end
      end

      def oldest_ancestor(ignore_abstract=false, ignore_placeholder=true)
        if parent_sig
          parent_sig.oldest_ancestor(ignore_abstract) ||
            begin
              if ignore_placeholder && parent_sig.placeholder?
                nil
              elsif ignore_abstract && parent_sig.abstract?
                nil
              else
                parent_sig
              end
            end
        else
          nil
        end
      end

      def add_field2(arg, hash={})
        opts = hash.merge :parent => sig_cls,
                          :name   => arg.name.to_s,
                          :type   => arg.type,
                          :expr   => arg._expr
        fld = Field.new opts
        @fields << fld
        sig_cls.add_method_for_field(fld)
        fld
      end

      def add_field(fld_name, fld_type, hash={})
        opts = hash.merge :parent => sig_cls,
                          :name   => fld_name.to_s,
                          :type   => fld_type
        fld = Field.new opts
        @fields << fld
        sig_cls.add_method_for_field(fld)
        fld
      end

      def add_inv_field_for(f)
        full_inv_type = ProductType.new(f.parent.to_atype, f.type).inv
        if full_inv_type.domain.klass != @sig_cls
          raise ArgumentError, "Field #{f} doesn't seem to belong in class #{@sig_cls}"
        end
        inv_fld = Field.new :parent => @sig_cls,
                            :name   => Arby.conf.inv_field_namer.call(f),
                            :type   => full_inv_type.full_range,
                            :inv    => f,
                            :synth  => true
        @inv_fields << inv_fld
        inv_fld
      end

      def [](sym) field(sym.to_s) end

      # Returns type associated with the given field
      #
      # @param fld [String, Symbol]
      # @return [AType]
      def field_type(fname)
        field(fname).type
      end

      # returns a string representation of the field definitions
      def fields_to_alloy() fld_list_to_alloy @fields  end

      # returns a string representation of the synthesized inv field definitions
      def inv_fields_to_alloy() fld_list_to_alloy @inv_fields end

      def fld_list_to_alloy(flds)
        flds.map {|f| "  " + f.to_alloy }
            .join(",\n")
      end

    end

  end
end
