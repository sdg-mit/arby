require 'arby/ast/types'
require 'arby/ast/utils'

module Arby
  module Ast

    class SigScope
      attr_reader :sig, :scope, :exact
      def initialize(sig, scope, exact=false)
        @sig, @scope, @exact = sig, scope, exact
      end

      def exact?() !!@exact end

      def to_s(sig_namer=nil)
        sig_namer ||= proc{|s| s.relative_name}
        sig_name = (@sig.is_a?(Class) && ASig > @sig) ? sig_namer[@sig] : @sig.to_s
        "#{@exact ? 'exactly ' : ''}#{@scope} #{sig_name}"
      end
    end

    class Scope
      attr_reader :global, :sig_scopes
      def initialize(global=4, sig_scopes=[])
        @global = global || 4
        @sig_scopes = sig_scopes
      end

      def clone() Scope.new(@global, @sig_scopes.dup) end

      def add_sig_scope(ss) @sig_scopes << ss end

      def extend_for_bounds(bnds)
        return self.clone unless bnds
        univ = bnds.extract_universe
        glbl = [@global, univ.sig_atoms.group_by{|a|
                  a.class.meta.oldest_ancestor || a.class
                }.map{|sig_cls, atoms|
                  atoms.size
                }.max].max
        ans = Scope.new(glbl, @sig_scopes)
        if ints = bnds.get_ints and !@sig_scopes.find{|ss| ss.sig == "Int"}
          bw = Math.log2(ints.max + 1).ceil + 1
          ans.add_sig_scope SigScope.new "Int", bw
        end
        ans
      end

      def to_s(sig_namer=nil)
        global_scope = @global ? "#{@global} " : ''
        sig_scopes = @sig_scopes.map{|ss| ss.to_s(sig_namer)}.join(', ')
        sig_scopes = "but #{sig_scopes}" unless sig_scopes.empty?
        "for #{global_scope}#{sig_scopes}"
      end

      def to_als(sig_namer=Arby.conf.alloy_printer.sig_namer)
        global_scope = @global ? "#{@global} " : ''
        sig_scopes = @sig_scopes.map{|ss| ss.to_s(sig_namer)}.join(', ')
        sig_scopes = "but #{sig_scopes}" unless sig_scopes.empty?
        "for #{global_scope}#{sig_scopes}"
      end

    end

  end
end
