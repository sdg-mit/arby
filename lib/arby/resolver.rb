require 'arby/arby_ast'

module Arby
  extend self

  # =================================================================
  # Class +CResolver+
  #
  # Type resolver.  Takes a sort of an Alloy unary type (+UnaryType+
  # or +ColType+) and resolves it to a +Class+.
  #
  # Options:
  #   :baseklass - expected base class of the resolved type.
  # =================================================================
  class CResolver
    BASEKLASS_OPT = :baseklass

    attr_reader :options

    def initialize(hash={})
      @options = hash.clone
    end

    # ----------------------------------------------------------------
    # @param col_type [UnaryType, ColType, String, Symbol, Class]
    # @return [Class]
    # ----------------------------------------------------------------
    def resolve_type(type)
      case type
      when Arby::Ast::UnaryType
        resolve_col_type(type.cls)
      when Arby::Ast::UnaryType::ColType
        resolve_col_type(type)
      when String, Symbol
        resolve_type(get_col_type(type))
      when Class
        type
      else
        nil
      end
    end

    # ----------------------------------------------------------------
    # Runs +#resolve_type+ and raises an error if +nil+ is returned.
    #
    # @raises ResolverError if type can not be resolved.
    # @raises TypeError if the resolved class is neither primitive nor
    #                   a subclass of a given base class.
    # ----------------------------------------------------------------
    def resolve_type!(type)
      baseklass = @options[BASEKLASS_OPT]
      cls = resolve_type(type)
      raise Arby::Ast::ResolveError, "unresolved type: #{type}: #{type.class}" unless cls
      raise Arby::Ast::TypeError, "type `#{cls}' is not a primitive type nor a #{baseklass.name}" unless baseklass.nil? || cls < baseklass || get_col_type(cls).primitive?
      cls
    end

    # ----------------------------------------------------------------
    # Takes a +ColType+ and returns a corresponding +Class+, or +nil+
    # if failed to resolve.
    #
    # @param col_type [ColType] @return [Class]
    # ----------------------------------------------------------------
    def resolve_col_type(col_type)
      case col_type
      when Arby::Ast::UnaryType::ColType::PrimitiveColType
        col_type.class.klass
      when Arby::Ast::UnaryType::ColType::RefColType
        col_type.src
      when Arby::Ast::UnaryType::ColType::UnresolvedRefColType
        src = col_type.src
        col_type.mod.send(:const_get, src.to_sym, false) rescue nil ||
          Arby.meta.sig(src.to_s) ||
          Arby.meta.find_sig(src.to_s) ||
          SDGUtils::MetaUtils.str_to_class(src.to_s)
      else
        nil
      end
    end

    protected

    def get_col_type(type)
      Arby::Ast::UnaryType::ColType.get(type)
    end
  end

  Resolver = Arby::CResolver.new :baseklass => Arby::Ast::ASig
  def resolver
    Arby::Resolver
  end

end
