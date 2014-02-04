require 'arby/dsl/errors'
require 'arby/ast/arg'
require 'arby/ast/type_consts'
require 'sdg_utils/dsl/missing_builder'

module Arby
  module Dsl

    module FieldsHelper
      extend self
      private

      def _decl_to_args(*decl_args)
        l_add_pending = lambda{|pending, dom, dest|
          pending.each{|sym| dest << Arby::Ast::Arg.new(:name => sym, :type => dom)}
        }

        decls = []
        pending_syms = []
        decl_args.each do |d|
          case d
          when String, Symbol
            pending_syms << d.to_sym
          when SDGUtils::DSL::MissingBuilder
            pending_syms << d.name
            d.consume
          when Hash
            _traverse_fields_hash d, proc{ |arg_name, dom|
              l_add_pending[pending_syms, dom, decls]
              pending_syms = []
              decls << Arby::Ast::Arg.new(:name => arg_name, :type => dom)
            }
          else
            raise SyntaxError, "wrong decl syntax: #{decl_args}"
          end
        end
        l_add_pending[pending_syms, Arby::Ast::TypeConsts::None, decls]
        decls
      end

      def _traverse_fields(hash, cont, &block)
        _traverse_fields_hash(hash, cont)
        unless block.nil?
          ret = block.call
          _traverse_fields_hash(ret, cont)
        end
        nil
      end

      def _traverse_fields_hash(hash, cont)
        return unless hash
        hash.each do |k,v|
          if Array === k
            k.each{|e| cont.call(e, v)}
          else
            cont.call(k, v)
          end
        end
      end

      # Invalid field format. Valid formats:
      #   - field name, type, options_hash={}
      #   - field name_type_hash, options_hash={}; where name_type_hash.size == 1
      #   - field hash                           ; where name,type = hash.first
      #                                            options_hash = Hash[hash.drop 1]
      def _traverse_field_args(args, cont)
        case
        when args.size == 3
          cont.call(*args)
        when args.size == 2
          if Hash === args[0] && args[0].size == 1
            cont.call(*args[0].first, args[1])
          else
            cont.call(*args)
          end
        when args.size == 1 && Hash === args[0]
          name, type = args[0].first
          cont.call(name, type, Hash[args[0].drop 1])
        else
          msg = """
Invalid field format. Valid formats:
  - field name, type, options_hash={}
  - field name_type_hash, options_hash={}; where name_type_hash.size == 1
  - field hash                           ; where name,type = hash.first
                                           options_hash = Hash[hash.drop 1]
"""
          raise ArgumentError, msg
        end
      end

    end

  end
end
