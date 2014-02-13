require 'arby/arby'
require 'arby/ast/op'
require 'arby/ast/expr_builder'
require 'arby/ast/field'
require 'arby/ast/types'
require 'arby/ast/type_consts'
require 'arby/utils/codegen_repo'
require 'arby/utils/expr_visitor'
require 'sdg_utils/meta_utils'

module Arby
  module Ast
    module Expr

      def self.as_atom(sig_inst, name, type=sig_inst.class, expr_mod=MAtomExpr)
        cls = sig_inst.singleton_class
        cls.send :include, expr_mod
        cls.class_eval <<-RUBY, __FILE__, __LINE__+1
          def __name() #{name.inspect} end
          def __type() @__atype ||= Arby::Ast::AType.get!(#{type.inspect}) end
        RUBY
        Expr.add_methods_for_type(sig_inst, AType.get!(type), false)
      end

      def self.add_methods_for_type(target_inst, type, define_type_method=true)
        cls = target_inst.singleton_class
        cls.send :define_method, :__type, lambda{type} if define_type_method
        range_cls = type.range.klass
        if (Arby::Ast::ASig > range_cls rescue false)
          add_field_methods cls, range_cls.meta.fields_including_sub_and_super
          add_field_methods cls, range_cls.meta.inv_fields_including_sub_and_super
          add_fun_methods   cls, range_cls.meta.all_funs
        elsif (Arby::Dsl::ModelDslApi >= range_cls rescue false)
          funs = range_cls.meta.opens.map(&:all_funs).flatten + range_cls.meta.all_funs
          add_fun_methods   cls, funs
        end
        if type.seq? || type.range.seq?
          #TODO: do it the right way
          seq_flds = [Field.new(:name   => :elems,
                                :parent => type,
                                :type   => type.remove_multiplicity.set_of),
                      Field.new(:name   => :inds,
                                :parent => type,
                                :type   => TypeConsts::Int.set_of)]
          add_field_methods cls, seq_flds
        end
      end

      def self.add_fun_methods(target_cls, funs)
        funs.each do |fun|
          target_cls.send :define_method, fun.name.to_sym do |*args|
            self.apply_call fun, *args
          end
        end
      end

      def self.add_field_methods(target_cls, fields)
        fields.each do |fld|
          fname = if fld.is_inv?
                    "#{fld.inv.getter_sym}!"
                  else
                    fld.getter_sym.to_s
                  end
          target_cls.send :define_method, "#{fname}" do
            self.apply_join fld.to_arby_expr
          end
          target_cls.send :define_method, "#{fname}=" do |val|
            ans = ExprBuilder.apply(Ops::ASSIGN, self.apply_join(fld.to_arby_expr), val)
            Arby.boss.add_side_effect(ans)
          end
        end
      end

      def self.ensure_type(expr)
        type = nil
        expr.respond_to?(:__type, true) and
          type = expr.__type
        if type.nil? || Arby::Ast::NoType === type
          fail "type not present in expr `#{expr}'"
        end
        type
      end

      def self.replace_subexpressions(e, orig, replacement)
        rbilder = Arby::Utils::ExprRebuilder.new do |expr|
          (expr.__id__ == orig.__id__) ? replacement : nil
        end
        rbilder.rebuild(e)
      end

      def self.to_conjuncts(e)
        if BinaryExpr === e && e.op == Ops::AND
          to_conjuncts(e.lhs) + to_conjuncts(e.rhs)
        else
          [e]
        end
      end

      def self.resolve_expr(e, parent=nil, kind_in_parent=nil, default_val=nil, &else_cb)
        if else_cb.nil?
          else_cb = proc { not_expr_fail(e, parent, kind_in_parent) }
        end
        case e
        when NilClass   then default_val || else_cb.call
        when Integer    then IntExpr.new(e)
        when MExpr      then e
        when AType      then TypeExpr.new(e)
        when TrueClass  then BoolConst::TRUE
        when FalseClass then BoolConst::FALSE
        when ASig       then e.to_arby_expr
        when Array
          if e.empty?
            ExprConsts::NONE
          elsif e.size == 1
            resolve_expr(e.first)
          else
            ExprBuilder.reduce_to_binary Arby::Ast::Ops::PLUS, *e.map{|i| resolve_expr(i)}
          end
        when Range
          if e.begin.is_a?(Integer) && e.end.is_a?(Integer)
            resolve_expr(e.to_a)
          else
            min = Expr.resolve_expr(e.begin)
            max = Expr.resolve_expr(e.end)
            TypeExpr.new(TypeConsts::Int).select{|i|
              if e.exclude_end?
                (i >= min).and(i < max)
              else
                (i >= min).and(i <= max)
              end
            }
          end
        when Proc
          resolve_expr e.call, parent, kind_in_parent, default_val
        when TupleSet
          if e.tuples.empty?
            ExprConsts.none_of(e.arity)
          else
            resolve_expr(e.tuples, e, "tuples")
          end
        when Tuple
          ExprBuilder.reduce_to_binary Ops::PRODUCT, *e.map{|a| resolve_expr(a, e, "atom")}
        when SDGUtils::DSL::MissingBuilder
          sig_cls = Arby.meta.find_sig(e.name)
          sig_cls ? sig_cls.to_arby_expr : else_cb.call
        when Class
          if e < ASig
            e.to_arby_expr
          else
            # try to find sig with the same name
            sig_cls = Arby.meta.find_sig(e.relative_name)
            sig_cls ? sig_cls.to_arby_expr : else_cb.call
          end
        else
          if e.respond_to? :to_arby_expr, true
            al_expr = e.send :to_arby_expr
            resolve_expr(al_expr, parent, kind_in_parent, default_val, &else_cb)
          else
            else_cb.call
          end
        end
      end

      def self.not_expr_fail(e, parent=nil, kind_in_parent=nil)
        kind = kind_in_parent ? "#{kind_in_parent} `#{e}'" : "#{e}"
        par = parent ? " in `#{parent}'" : ""
        fail "#{kind} is not an expression#{par}, but is `#{e.class}'"
      end

      # ============================================================================
      # == Module +MExpr+
      #
      # Represents an Alloy expression that is upon creation always
      # "executed" either concretely or symbolically (not all
      # expressions support both execution modes.
      # ============================================================================
      module MExpr
        include Ops

        def self.included(base)
          base.class_eval <<-RUBY, __FILE__, __LINE__+1
          def self.new(*args, &block)
            expr = allocate
            expr.send :initialize, *args, &block
            expr.exe
          end
          RUBY
        end

        attr_reader :__type, :__op
        def __op() @__op || Ops::UNKNOWN end
        def op() __op end #TODO remove

        def __eq(other)  self.__id__ == other.__id__ end
        def __neq(other) !__eq(other) end

        def initialize(type=nil)
          set_type(type)
        end

        def coerce(other)
          other_expr = Expr.resolve_expr(other)
          [other_expr, self]
        rescue
          raise TypeError, "#{self.class} can't be coerced into #{other.class}"
        end

        def set_type(type=nil)
          @__type = Arby::Ast::AType.get!(type) if type
          if @__type && !@__type.univ? && !@__type.empty?
            Expr.add_methods_for_type(self, @__type, false)
          end
        end

        def exe
          case
          when Arby.symbolic_mode?; exe_symbolic
          when Arby.concrete_mode?; exe_concrete
          else fail "unknown mode: #{mode}"
          end
        end

        def exe_symbolic() self end
        def exe_concrete() self end

        def is_disjunction() false end
        def is_conjunction() false end

        def to_conjuncts() Expr.to_conjuncts(self) end

        def ==(other)        ExprBuilder.apply(EQUALS, self, other) end
        def !=(other)        ExprBuilder.apply(NOT_EQUALS, self, other) end

        def +(other)         pick_and_apply(IPLUS, PLUS, self, other) end
        def -(other)         pick_and_apply(IMINUS, MINUS, self, other) end
        def /(other)         pick_and_apply(DIV, MINUS, self, other) end
        def merge(other)     ExprBuilder.apply(PLUSPLUS, self, other) end
        def *(other)         ExprBuilder.apply(MUL, self, other) end
        def %(other)         ExprBuilder.apply(REM, self, other) end
        def <<(other)        ExprBuilder.apply(SHL, self, other) end
        def >>(other)        ExprBuilder.apply(SHA, self, other) end

        def **(other)        ExprBuilder.apply(PRODUCT, self, other) end
        def [](other)        ExprBuilder.apply(SELECT, self, other)  end
        def <(other)         ExprBuilder.apply(LT, self, other) end
        def <=(other)        ExprBuilder.apply(LTE, self, other) end
        def >(other)         ExprBuilder.apply(GT, self, other) end
        def >=(other)        ExprBuilder.apply(GTE, self, other) end
        def <=>(other)       ExprBuilder.apply(IFF, self, other) end

        def in?(other)       ExprBuilder.apply(IN, self, other) end
        def not_in?(other)   ExprBuilder.apply(NOT_IN, self, other) end
        def contains?(other) ExprBuilder.apply(IN, other, self) end

        def &(other)         ExprBuilder.apply(INTERSECT, self, other) end
        # def *(other)         join_closure(RCLOSURE, other) end
        # def ^(other)         join_closure(CLOSURE, other) end

        def ~(arg=nil)
          if arg
            ExprBuilder.apply(JOIN, self, ExprBuilder.apply(TRANSPOSE, arg))
          else
            ExprBuilder.apply(TRANSPOSE, self)
          end
        end

        def domain(other)    ExprBuilder.apply(DOMAIN, self, other) end
        def range(other)     ExprBuilder.apply(RANGE, self, other) end
        def closure()        ExprBuilder.apply(CLOSURE, self) end
        def rclosure()       ExprBuilder.apply(RCLOSURE, self) end
        def !()              ExprBuilder.apply(NOT, self) end
        def empty?()         ExprBuilder.apply(NO, self) end
        def lone?()          ExprBuilder.apply(LONE, self) end
        def no?(&blk)        _quant_or_mod(:no, NO, &blk) end
        def some?(&blk)      _quant_or_mod(:exist, SOME, &blk) end
        def one?(&blk)       _quant_or_mod(:one, ONE, &blk) end
        def all?(&blk)       _blk_to_quant(:all, &blk) end
        def select(&blk)     _blk_to_quant(:setcph, &blk) end

        def and(other)       ExprBuilder.apply(AND, self, other) end
        def or(other)        ExprBuilder.apply(OR, self, other) end
        def implies(other)   ExprBuilder.apply(IMPLIES, self, other) end
        def size()           ExprBuilder.apply(CARDINALITY, self) end

        def apply_call(fun, *args) ExprBuilder.apply_call(self, fun, *args) end
        def apply_join(other)      ExprBuilder.apply(JOIN, self, other) end
        alias_method :join,    :apply_join
        alias_method :call,    :apply_join
        alias_method :product, :**

        def pick_and_apply(int_op, rel_op, *args)
          op = if args.first.respond_to?(:__type, true) &&
                   args.first.__type &&
                   args.first.__type.primitive?
                 int_op
               else
                 rel_op
               end
          ExprBuilder.apply(op, *args)
        end

        def join_closure(closure_op, other)
          closure_operand = case other
                            when MExpr; other
                            when String, Symbol;
                              #TODO this is just ugly
                              joined = self.send other #returns a "join" BinaryExpr
                              joined.rhs
                            end
          ExprBuilder.apply(JOIN, self, ExprBuilder.apply(closure_op, closure_operand))
        end

        def method_missing(sym, *args, &block)
          return super if Arby.is_caller_from_arby?(caller[0])
          if args.empty?
            return super unless Arby.conf.sym_exe.convert_missing_fields_to_joins
            ExprBuilder.apply(JOIN, self, Var.new(sym))
          elsif args.size == 1 && Arby::Dsl::ModBuilder === args.first &&
              args.first.pending_product?
            modb = args.first
            self.join(Var.new(sym)).product(modb)
          else
            return super unless Arby.conf.sym_exe.convert_missing_methods_to_fun_calls
            apply_call sym, *args
            # if sym == :[] && args.size == 1
            #   lhs = (MExpr === args[0]) ? args[0] : Var.new(args[0])
            #   lhs.apply_join ParenExpr.new(self)
            # else
            #   #TODO do something when `sym == :[]' and args.size > 1:
            #   #     either fail or convert into multistep join
            #   apply_call sym, *args
            # end
          end
        end

        def to_str
          to_s
        end

        protected

        def _quant_or_mod(quant_kind, mod_op, &blk)
          blk ? _blk_to_quant(quant_kind, &blk) : ExprBuilder.apply(mod_op, self)
        end

        # @param kind [:all, :some, :comprehension]
        def _blk_to_quant(kind, &blk)
          type = self.__type #Expr.ensure_type(self)
          arity = blk.arity
          if type
            msg = "block must have same arity as lhs type: \n" +
                  "  block arity: #{blk.arity}\n" +
                  "  type arity: #{type.arity} (#{type})"
            fail msg unless arity == type.arity
          end
          domain = self
          if arity == 1
            args = [Arby::Ast::Arg.new(blk.parameters[0][1], domain)]
            body = blk
          else
            Expr.ensure_type(self)
            args = type.each_with_index.map{ |col_type, idx|
              Arby::Ast::Arg.new(blk.parameters[idx][1], col_type)
            }
            body = proc { |*args|
              tuple = ExprBuilder.reduce_to_binary(PRODUCT, *args)
              ExprBuilder.apply(IMPLIES, domain.contains?(tuple), blk.call(*args))
            }
          end
          QuantExpr.send kind, args, body
        end

      end


      # ============================================================================
      # == Class +BoolConst+
      #
      # Represents a boolean constant.
      # ============================================================================
      class BoolConst
        include MExpr
        attr_reader :value

        private

        def initialize(val)
          @value = val
        end

        public

        TRUE  = BoolConst.new(true)
        FALSE = BoolConst.new(false)

        # def self.True()  TRUE end
        # def self.False() FALSE end
        def self.True?(ex)          is_obj_equal(TRUE, ex) end
        def self.False?(ex)         is_obj_equal(FALSE, ex) end
        def self.Const?(ex)         True?(ex) || False?(ex) end
        def self.is_obj_equal(l, r) l.__id__ == r.__id__ end

        def to_s
          "#{value}"
        end
      end

      # ============================================================================
      # == Module +MVarExpr+
      #
      # Represents a symbolic variable.
      # ============================================================================
      module MVarExpr
        include MExpr
        attr_reader :__name
        def initialize(name, type=nil)
          super(type)
          unless String === name || Symbol === name
            fail "Expected String or Symbol for Var name, got #{name}:#{name.class}"
          end
          @__name = name
        end
        def __op()   Ops::NOOP end
        def to_s() "#{__name}" end
      end

      # ============================================================================
      # == Class +Var+
      #
      # Represents a symbolic variable.
      # ============================================================================
      class Var
        include MVarExpr
      end

      # ============================================================================
      # == Class +FieldExpr+
      #
      # TODO
      # ============================================================================
      class FieldExpr < Var
        attr_reader :__field
        def initialize(fld)
          @__field = fld
          super(fld.name, fld.full_type)
        end
        def to_s() __field.name end
        def exe_concrete() __field end
      end

      # ============================================================================
      # == Class +SigExpr+
      #
      # TODO
      # ============================================================================
      class SigExpr < Var
        attr_reader :__sig
        def initialize(sig)
          TypeChecker.check_sig_class(sig)
          super(sig.relative_name, sig.to_atype)
          @__sig = sig
        end
        def to_s()         @__sig ? @__sig.relative_name : "" end
        def exe_concrete() @__sig end
      end

      # ============================================================================
      # == Class +AtomExpr+
      #
      # TODO
      # ============================================================================
      class AtomExpr < Var
        attr_reader :__atom, :__sig
        def initialize(atom)
          sig = atom.class
          TypeChecker.check_sig_class!(sig)

          # check if singleton PI sig exists
          if atom_id = atom.__alloy_atom_id
            #TODO: should not rely on subsigs,
            #      because they don't have to belong to the current model
            pi_sig = sig.meta.subsigs.find{|s| s.meta.atom? && s.meta.atom_id == atom_id}
            fail "pi sig not found for atom #{atom}" unless pi_sig
            sig = pi_sig
          end
          super(sig.relative_name, sig.to_atype)
          @__sig = sig
          @__atom = atom
        end
        def to_s()         @__atom.__label end
        def exe_concrete() @__atom end
      end

      # ============================================================================
      # == Class +TypeExpr+
      #
      # TODO
      # ============================================================================
      class TypeExpr < Var
        def initialize(type, name=nil)
          super(name || type.to_s, type)
        end
        def exe_concrete() __type end
      end

      # ============================================================================
      # == Class +IntExpr+
      #
      # TODO
      # ============================================================================
      class IntExpr
        include MExpr
        attr_reader :__value
        def initialize(value)
          #TODO: define some constants in AType for built-in types
          super(Arby::Ast::TypeConsts::Int)
          @__value = value
          @__op = Ops::NOOP
        end
        def exe_concrete() __value end
        def to_s()         __value.to_s end
      end

      # ============================================================================
      # == Module +MAtom+
      #
      # TODO
      # ============================================================================
      module MAtomExpr
        include MVarExpr

        def method_missing(sym, *args, &block)
          if send(:respond_to?, :__parent, true) && p=__parent()
            p.send sym, *args, &block
          elsif args.size == 1 && Arby::Dsl::ModBuilder === args.first &&
              args.first.pending_product?
            lhs = Arby.meta.find_sig(sym) or raise ::NameError, "`#{sym}' not found"
            modb = args.first
            be = ExprBuilder.apply(Ops::PRODUCT, lhs, modb.rhs_type)
            be.instance_variable_set "@left_mult", modb.mod_smbl
            be
          elsif not Arby.is_caller_from_arby?(caller[0])
            SDGUtils::DSL::MissingBuilder.new(sym, &block)
          else
            super#raise ::NameError, "method `#{sym}' not found in #{self}:#{self.class}"
          end
        end

        def to_s() @__name end
      end

      # ============================================================================
      # == Module +MImplicitInst+
      #
      # TODO
      # ============================================================================
      module MImplicitInst
        include MAtomExpr
        def apply_join(other) other end
        def to_s() "super" end
      end

      # ============================================================================
      # == Class +NaryExpr+
      #
      # Represents an n-ary expression.
      # ============================================================================
      class NaryExpr
        include MExpr
        # TODO: rename refactor...
        attr_reader :children

        def initialize(op, *children)
          @__op = op
          @children = children
        end

        def exe_symbolic
          if children.all?{|ch| MExpr === ch}
            self
          else
            chldrn = children.map{|ch| Expr.resolve_expr(ch, self, "operand")}
            self.class.new op, *chldrn
          end
        end

        def is_disjunction() op == Ops::OR end
        def is_conjunction() op == Ops::AND end

        protected

        def self.add_constructors_for_ops(ops)
          ops.each do |op|
            class_eval <<-RUBY, __FILE__, __LINE__+1
              def self.#{op.name}(*args)
                self.new(Arby::Ast::Op.by_name(#{op.name.inspect}), *args)
              end
            RUBY
          end
        end
      end

      # ============================================================================
      # == Class +UnaryExpr+
      #
      # Represents a unary expression.
      # ============================================================================
      class UnaryExpr < NaryExpr
        def initialize(op, sub) super(op, sub) end
        def sub()               children.first end

        add_constructors_for_ops Arby::Ast::Op.by_arity(1)

        def to_s
          "(#{op} #{sub})"
        end
      end

      # ============================================================================
      # == Class +ParenExpr+
      #
      # Represents an expression enclosed in parens.
      # ============================================================================
      class ParenExpr
        include MExpr

        attr_reader :sub
        def initialize(sub) @sub = sub end

        def exe_symbolic
          if MExpr === sub
            self
          else
            ParenExpr.new Expr.resolve_expr(sub)
          end
        end

        def to_s() "(#{sub})" end
      end

      # ============================================================================
      # == Class +BinaryExpr+
      #
      # Represents a binary expression.
      # ============================================================================
      class BinaryExpr < NaryExpr
        attr_reader :left_mult

        def initialize(op, lhs, rhs, left_mult=nil)
          super(op, lhs, rhs)
          @left_mult = left_mult
        end
        def lhs()                    children[0] end
        def rhs()                    children[1] end

        add_constructors_for_ops Arby::Ast::Op.by_arity(2)

        def to_s
          op_str = op.to_s
          op_str = " #{left_mult}#{op_str} " unless op_str == "."
          "#{lhs}#{op_str}#{rhs}"
        end
      end

      # ============================================================================
      # == Class +CallExpr+
      #
      # Represents a function call.
      # ============================================================================
      class CallExpr
        include MExpr
        attr_reader :target, :fun, :args

        def initialize(target, fun, *args)
          @target, @fun, @args = target, fun, args
        end

        def __op() (has_target?) ? Ops::JOIN : Ops::SELECT end

        def has_target?() !!target && !(MImplicitInst === target) end

        def exe_symbolic
          if (MExpr === target || target.nil?) && args.all?{|a| MExpr === a}
            self
          else
            t = Expr.resolve_expr(target, self, "target") unless target.nil?
            as = args.map{|a| Expr.resolve_expr(a, self, "argument")}
            self.class.new t, fun, *as
          end
        end

        def to_s
          pre = target ? "#{target}." : ""
          "#{pre}#{fun}[#{args.join(', ')}]"
        end
      end

      # ============================================================================
      # == Class +ITEExpr+
      #
      # Represents an "if-then-else" expression.
      # ============================================================================
      class ITEExpr
        include MExpr
        attr_reader :cond, :then_expr, :else_expr
        def initialize(cond, then_expr, else_expr)
          @cond, @then_expr, @else_expr = cond, then_expr, else_expr
          @__op = Ops::IF_ELSE
        end

        def exe_symbolic
          case
          when MExpr === cond && MExpr === then_expr && MExpr === else_expr
            self
          else
            cnd = Expr.resolve_expr(cond, self, "ite cond")
            te = Expr.resolve_expr(then_expr, self, "then branch", BoolConst::TRUE)
            ee = Expr.resolve_expr(else_expr, self, "else branch", BoolConst::TRUE)
            ITEExpr.new(cnd, te, ee)
          end
        end

        def to_s
"""
  (#{cond}) implies {
    #{then_expr}
  } else {
    #{else_expr}
  }
"""
        end
      end

      # ============================================================================
      # == Class +QuantExpr+
      #
      # Represents a first-order quantifier expression.
      #
      # @attribute decl [Array(Arg)]
      # @attribute body [Proc, MExpr]
      # ============================================================================
      class QuantExpr
        include MExpr
        attr_reader :decl, :body

        def self.all(decl, body)   self.new(Ops::ALLOF, decl, body) end
        def self.no(decl, body)    self.new(Ops::NONEOF, decl, body) end
        def self.exist(decl, body) self.new(Ops::SOMEOF, decl, body) end
        def self.one(decl, body)   self.new(Ops::ONEOF, decl, body) end
        def self.lone(decl, body)  self.new(Ops::LONEOF, decl, body) end
        def self.let(decl, body)   self.new(Ops::LET, decl, body) end
        def self.setcph(decl, body)
          ans = self.new(Ops::SETCPH, decl, body)
          #TODO: not quite right
          Expr.add_methods_for_type(ans, decl.last.type) if decl.last.type
          ans
        end

        def all?()           op == Ops::ALLOF end
        def exist?()         op == Ops::SOMEOF end
        def let?()           op == Ops::LET end
        def comprehension?() op == Ops::SETCPH end

        def kind()   op.sym end
        def arity()  decl.size end

        def exe_symbolic
          case body
          when MExpr; self
          else
            wrapped_body = (Proc === body) ? wrap(body) : body
            b = Expr.resolve_expr(wrapped_body, self, "body", BoolConst::TRUE)
            decl.each(&:expr) #resolve decl expressions
            QuantExpr.new(op, decl, b)
          end
        end

        def to_s
          decl_str = decl.map{|a| "#{a.name}: #{a.expr}"}.join(", ")
          if comprehension?
            "{#{decl_str} | #{body}}"
          else
            "#{kind} #{decl_str} {\n" +
            "  #{body}\n" +
            "}"
          end
        end

        private

        def initialize(op, decl, body)
          @__op, @decl, @body = op, decl, body
          fail unless Qop === @__op
          # fake_body_src = "<failed to extract body source>"
          # @body_src = Arby::Utils::CodegenRepo.proc_to_src(body) || fake_body_src
        end

        def wrap(proc)
          vars = decl.reduce({}) do |acc, arg|
            acc[arg.name] = Var.new(arg.name, arg.type)
            acc
          end
          proc {
            SDGUtils::ShadowMethods.shadow_methods_while(vars, &proc)
          }
        end
      end

      module ExprConsts
        extend self

        IDEN  = Var.new("iden")
        NONE  = Var.new("none")
        UNIV  = TypeExpr.new(TypeConsts::Univ, "univ")
        TRUE  = BoolConst::TRUE
        FALSE = BoolConst::FALSE

        def Iden() ExprConsts::IDEN end
        def iden() ExprConsts::IDEN end

        def None() ExprConsts::NONE end
        def none() ExprConsts::NONE end

        def Univ() ExprConsts::UNIV end
        def univ() ExprConsts::UNIV end

        def True() ExprConsts::TRUE end
        def true() ExprConsts::TRUE end

        def False() ExprConsts::FALSE end
        def false() ExprConsts::FALSE end

        def none_of(arity)
          if arity == 1
            NONE
          else
            ExprBuilder.reduce_to_binary(Ops::PRODUCT, *arity.times.map{NONE})
          end
        end
      end

    end
  end
end

