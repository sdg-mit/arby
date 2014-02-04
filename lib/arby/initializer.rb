require 'arby/arby_meta'
require 'arby/arby_conf'
require 'arby/resolver.rb'

module Arby

  # =================================================================
  # Class +CInitializer+
  #
  # Performs various initialization tasks.
  #
  # Options:
  #   :resolver  - resolver to use, defaults to +Arby::Resolver+
  #   :baseklass - base class for types for which to add inverse
  #                fields, defaults to +Arby::Ast::Sig+.
  # =================================================================
  class CInitializer
    RESOLVER_OPT = :resolver
    BASEKLASS_OPT = :baseklass

    @@resolved  = false
    @@added_inv = false

    attr_reader :options

    def initialize(hash={})
      opt = hash.clone
      opt[RESOLVER_OPT] ||= Arby::Resolver
      opt[BASEKLASS_OPT] ||= Arby::Ast::Sig
      @options = opt
    end

    # ----------------------------------------------------------------
    # Initializes everything and freezes most of the meta stuff.
    # ----------------------------------------------------------------
    def init_all
      init_all_no_freeze
      deep_freeze
    end

    # ----------------------------------------------------------------
    # Initializes everything.
    # ----------------------------------------------------------------
    def init_all_no_freeze
      resolve_fields
      init_inv_fields
      eval_sig_bodies
    end

    # ----------------------------------------------------------------
    # Goes through all the fields, searches for
    # +UnresolvedRefColType+, resolves them and updates the field
    # information.
    # ----------------------------------------------------------------
    def resolve_fields(force=false)
      return unless force || Arby.test_and_set(:fields_resolved)

      logger = Arby.conf.logger
      flds = Arby.meta.sigs.map{|s| s.meta.fields}.flatten
      funs = Arby.meta.sigs.map{|s| s.meta.funs + s.meta.preds}.flatten
      types = flds.map(&:type) + funs.map(&:full_type)
      types.each do |type|
        # logger.debug "[resolve_fields] checking field #{f}"
        type.each do |utype|
          col_type = utype.cls
          if col_type.instance_of? Arby::Ast::UnaryType::ColType::UnresolvedRefColType
            logger.debug "[resolve_fields]   trying to resolve #{col_type}..."
            cls = @options[RESOLVER_OPT].resolve_type!(col_type)
            logger.debug "[resolve_fields]     resolved to #{cls}"
            utype.update_cls(cls)
          end
        end
      end
    end

    # ----------------------------------------------------------------
    # Creates inverse fields for the user-defined fields.
    # ----------------------------------------------------------------
    def init_inv_fields(force=false)
      return unless force || Arby.test_and_set(:inv_fields_added)

      logger = Arby.conf.logger
      Arby.meta.sigs.each do |r|
        r.meta.pfields.each do |f|
          unless f.inv
            logger.debug "[init_inv_fields] checking field #{f}"
            range_cls = f.type.range.cls.klass
            if range_cls < @options[BASEKLASS_OPT]
              logger.debug "[init_inv_fields]   defining inverse of #{f}"
              invfld = range_cls.send(:_add_inv_for_field, f)
              logger.debug "[init_inv_fields]     #{invfld} defined"
            end
          end
        end
      end
    end

    # ----------------------------------------------------------------
    # Goes throug all the fields, searches for +UnresolvedRefColType+,
    # resolves them and updates the field information.
    # ----------------------------------------------------------------
    def eval_sig_bodies(force=false)
      return unless Arby.conf.defer_body_eval
      return unless force || Arby.test_and_set(:sig_bodies_evaluated)
      Arby.meta.sig_builders.each(&:eval_body_now!)
    end

    # ----------------------------------------------------------------
    # Freezes most of the meta stuff.
    # ----------------------------------------------------------------
    def deep_freeze
      sig_metas = Arby.meta.sigs.map &:meta
      funs = sig_metas.map{|s| s.funs + s.preds}.flatten
      flds = sig_metas.map{|s| s.fields + s.inv_fields}.flatten
      args = funs.map(&:args).flatten
      # [Arby.conf, Arby.meta, *sig_metas, *flds, *args].each(&:freeze)
      [Arby.conf, Arby.meta, *flds, *args].each(&:freeze)
    end
  end

end
