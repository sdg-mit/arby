require 'arby/bridge/solver_helpers'
require 'arby/utils/alloy_printer'
require 'sdg_utils/caching/searchable_attr'
require 'sdg_utils/event/events'
require 'sdg_utils/meta_utils'
require 'sdg_utils/random'

module Arby
  extend self

  module Model

    module MMUtils
      include SDGUtils::Caching::SearchableAttr

      def self.included(base)
        base.extend SDGUtils::Caching::SearchableAttr::Static
      end

      def clear_restriction
        restrict_to nil
      end

      def restrict_to(mod)
        @restriction_mod = mod
        respond_to? :clear_caches and self.clear_caches()
      end

      protected

      def _restrict(src)
        return src unless @restriction_mod
        src.select {|e| e.name && e.name.start_with?(@restriction_mod.to_s)}
      end
    end

    # ==================================================================
    # == Class +MetaModel+
    # ==================================================================
    class MetaModel
      include MMUtils
      include SDGUtils::Events::EventProvider
      include Arby::Bridge::SolverHelpers

      def initialize
        reset
      end

      def reset
        @models = []
        @sigs = []
        @sig_builders = []
        @restriction_mod = nil
        @cache = {}
      end

      attr_searchable :model, :sig

      def all_reachable_sigs() sigs end
      def reachable_sigs()     sigs end
      def reachable_fields()   reachable_sigs().map{|s| s.meta.pfields}.flatten end

      # @param sig_cls [Class]
      def has_sig(sig_cls) _restrict(@sigs).member?(sig_cls) end

      def add_sig_builder(sb)
        @sig_builders << sb
        @opened_model and @opened_model.send(:add_sig_builder, sb)
      end

      def sig_builders()
        @sig_builders.clone
      end

      def open_model(mod)
        @opened_model =
          case mod
          when String, Symbol
            model!(mod.to_s)
          when Arby::Ast::Model
            mod
          else
            raise ArgumentError, "#{mod}:#{mod.class} is neither String nor Model"
          end
      end

      def close_model(mod)
        msg = "#{mod} is not the currently opened model"
        raise ArgumentError, msg unless @opened_model == mod
        @opened_model = nil
      end

      def clear_caches
        _clear_caches :sig, :model
      end

      def to_als
        Arby::Utils::AlloyPrinter.export_to_als
      end

    end

  end
end
