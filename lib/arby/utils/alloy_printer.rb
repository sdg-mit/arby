require 'arby/arby_ast'
require 'sdg_utils/config'
require 'sdg_utils/visitors/visitor'
require 'sdg_utils/print_utils/code_printer'

module Arby
  module Utils

    class AlloyPrinter
      include Arby::Ast::Ops

      def self.export_to_als(*what)
        ap = AlloyPrinter.new
        what = Arby.meta.models if what.empty?
        what.each{|e| ap.send :to_als, e}
        ap.to_s
      end

      def export_to_als(*what)
        old_out = @out
        @out = new_code_printer
        what.each{|e| to_als e}
        ans = @out.to_s
        @out = old_out
        ans
      end

      def to_s
        @out.to_s
      end

      protected

      def initialize(config={})
        @out = new_code_printer
        @conf = Arby.conf.alloy_printer.extend(config)
      end

      # def add_name_mapping(x, name) @name_map[x] = name end

      def new_code_printer
        SDGUtils::PrintUtils::CodePrinter.new :visitor => self,
                                              :visit_method => :export_to_als
      end

      def to_als(arby_obj)
        _fail = proc{fail "Unrecognized Arby entity: #{arby_obj}:#{arby_obj.class}"}
        case arby_obj
        when Arby::Ast::Model; model_to_als(arby_obj)
        when Class
          if arby_obj < Arby::Ast::ASig
            sig_to_als(arby_obj)
            # sig_cls = arby_obj
            # if sig_cls.meta.enum?
            #   enum_to_als(sig_cls)
            # elsif not sig_cls.meta.enum_const?
            #   sig_to_als(arby_obj)
            # end
          else
            _fail[]
          end
        when Arby::Ast::Fun;          fun_to_als(arby_obj)
        when Arby::Ast::Command;      command_to_als(arby_obj)
        when Arby::Ast::Field;        field_to_als(arby_obj)
        when Arby::Ast::AType;        type_to_als(arby_obj)
        when Arby::Ast::Arg;          arg_to_als(arby_obj)
        when Arby::Ast::Expr::MExpr;  expr_to_als(arby_obj)
        when NilClass;                ""
        else
          _fail[]
        end
      end

      def model_to_als(model)
        history = @history ||= Set.new
        return if history.member?(model)
        history << model

        if @in_opened_module
          @out.pl "// ============================================="
          @out.pl "// == module #{model.relative_name}"
        else
          # module name (useless)
          @out.pl "module #{model.relative_name}"

          # print builtin opens
          model.all_reachable_sigs.select(&:ordered?).each do |s|
            sname = @conf.sig_namer[s]
            @out.pl "open util/ordering[#{sname}] as #{sname}_ord"
          end
        end

        @out.pl

        # print open decsl
        was_open = @in_opened_module
        @in_opened_module = true
        @out.pn model.opens, "\n"
        @in_opened_module = was_open

        # print sigs
        sigs = model.sigs #.reject{|s| s.meta.enum_const?}
        @out.pn sigs, "\n"

        # print funs
        unless model.all_funs.empty?
          @out.pl
          @out.pn model.all_funs, "\n"
        end

        # print commands
        unless model.commands.empty?
          @out.pl
          @out.pn model.commands, "\n"
        end

        if @in_opened_module
          @out.pl "// -------------------------------------------\n"
        end
      end

      def enum_to_als(sig)
        sig_name = @conf.sig_namer[sig]
        enums = sig.meta.subsigs.map{|e| @conf.sig_namer[e]}.join(", ")
        @out.pl "enum #{sig_name} {#{enums}}"
      end

      def sig_to_als(sig)
        psig = sig.superclass
        abs_str = (mult=sig.meta.multiplicity) ? "#{mult} " : ""
        psig_str = (psig != Arby::Ast::Sig) ? "extends #{@conf.sig_namer[psig]}" : ""
        sig_name = @conf.sig_namer[sig]
        @out.p "#{abs_str}sig #{sig_name} #{psig_str} {"
        flds = sig.meta.fields.reject(&:transient?)
        unless flds.empty?
          @out.pl
          @out.in do
            @out.pn flds, ",\n"
          end
          @out.pl
        end
        @out.p "}"
        if sig.meta.facts.empty?
          @out.pl
        else
          @in_appended_facts = true
          @out.pl " {"
          @out.in do
            @out.pn sig.meta.facts.map{|f| f.sym_exe("this").to_conjuncts}.flatten, "\n"
          end
          @out.pl
          @out.pl "}"
          @in_appended_facts = false
        end
        funs = sig.meta.funs + sig.meta.preds
        @out.pl unless funs.empty?
        @out.pn funs, "\n"
      end

      def field_to_als(fld)
        @out.p "#{@conf.arg_namer[fld]}: "
        @out.pn [fld.expr]
      end

      def fun_to_als(fun)
        args = fun.args
        fun_name = @conf.fun_namer[fun]
        is_inst_fun = Class === fun.owner && fun.owner.is_sig?
        if is_inst_fun
          # selfarg = Arby::Ast::Arg.new :name => "self", :type => fun.owner
          # [selfarg] + fun.args
          fun_name = "#{@conf.sig_namer[fun.owner]}.#{fun_name}"
        end
        args_str = args.map(&method(:export_to_als)).join(", ")
        params_str = if args.empty? #&& !fun.fun? && !fun.pred?
                       ""
                     else
                       "[#{args_str}]"
                     end
        ret_str = if fun.fun?
                    ": #{export_to_als fun.ret_type}"
                  else
                    ""
                  end
        kind = if fun.assertion?
                 :assert
               else
                 fun.kind
               end
        @out.pl "#{kind} #{fun_name}#{params_str}#{ret_str} {"
        @out.in do
          fun_body = is_inst_fun ? fun.sym_exe("this") : fun.sym_exe
          @out.pn fun_body.to_conjuncts, "\n" if fun_body
        end
        @out.pl "\n}"
      end

      def command_to_als(cmd)
        cmd_name = cmd.name.to_s
        if cmd.fun && cmd.fun.body
          name = (cmd.name.empty?) ? "" : "#{cmd_name} "
          @out.p "#{cmd.kind} #{name}"
          @out.pl "{"
          @out.in do
            @out.pn [cmd.fun.sym_exe]
          end
          @out.pl
          @out.p "} "
        else
          pred = @history.to_a.reverse.map(&:preds).flatten.find{|p| p.name.to_s==cmd_name}
          name = pred ? @conf.fun_namer[pred] : cmd_name
          @out.p "#{cmd.kind} #{name} "
        end
        @out.pl "#{cmd.scope.to_s(@conf.sig_namer)}"
      end

      def type_to_als(type)
        if type.is_a?(Arby::Ast::FldRefType)
          @out.p @conf.arg_namer[type.fld]
        else
          case type
          when Arby::Ast::NoType
            @out.p "univ"
          when Arby::Ast::UnaryType
            cls = type.klass
            if type.univ?
              @out.p "univ"
            elsif cls < Arby::Ast::ASig
              @out.p @conf.sig_namer[cls]
            elsif sig_cls = @history.first.find_sig(type.cls.to_s.relative_name)
              @out.p @conf.sig_namer[sig_cls]
            else
              @out.p type.cls.to_s.relative_name
            end
          when Arby::Ast::ProductType
            @out.pn [type.lhs]
            @out.p " #{type.left_mult}-> "
            @out.p "(" if type.rhs.arity > 1
            @out.pn [type.rhs]
            @out.p ")" if type.rhs.arity > 1
          when Arby::Ast::ModType
            @out.p "#{type.mult} "
            @out.p "(" if type.arity > 1
            @out.pn [type.type]
            @out.p ")" if type.arity > 1
          else
            @out.p type.to_s
          end
        end
      end

      def arg_to_als(arg)
        @out.p "#{arg.name}: #{export_to_als arg.expr}"
      end

      def expr_visitor()
        @expr_visitor ||= SDGUtils::Visitors::TypeDelegatingVisitor.new(self,
          :top_class => Arby::Ast::Expr::MExpr,
          :visit_meth_namer => proc{|cls, kind| "#{kind}_to_als"}
        )
      end

      def expr_to_als(expr)
        expr_visitor.visit(expr.exe_symbolic)
      end

      def typeexpr_to_als(expr)
        type_to_als(expr.__type)
      end

      def mexpr_to_als(expr)
        @out.p expr.to_s
      end

      def mvarexpr_to_als(v)
        @out.p v.__name
      end

      def atomexpr_to_als(ae)
        @out.p @conf.sig_namer[ae.__sig]
      end

      def fieldexpr_to_als(fe)
        fld = fe.__field
        fld_name = if fld.ordering?
                     "#{@conf.sig_namer[fld.owner]}_ord/#{fld.name}"
                   elsif fld.virtual?
                     fld.name
                   else
                     @conf.arg_namer[fld]
                   end
        if @in_appended_facts
          @out.p "@#{fld_name}"
        else
          @out.p "#{fld_name}"
        end
      end

      def quantexpr_to_als(expr)
        decl_str = expr.decl.map(&method(:export_to_als)).join(", ")
        expr_kind = case expr.kind
                    when :exist; "some"
                    else expr.kind
                    end
        if expr.comprehension?
          @out.p "{#{decl_str} | "
          @out.pn [expr.body]
          @out.p "}"
        else
          if expr.let?
            expr.decl.each do |a|
              decl_str = decl_str.sub "#{a.name}:", "#{a.name} ="
            end
          end
          @out.pl "#{expr_kind} #{decl_str} {"
          @out.in do
            @out.pn expr.body.to_conjuncts, "\n"
          end
          @out.pl "\n}"
        end
      end

      def iteexpr_to_als(ite)
        @out.pl "#{enclose ite.op, ite.cond} implies {"
        @out.in do
          @out.pn [ite.then_expr]
        end
        @out.pl
        @out.p "}"
        unless Arby::Ast::Expr::BoolConst === ite.else_expr
          @out.pl " else {"
          @out.in do
            @out.pn [ite.else_expr]
          end
          @out.pl
          @out.p "}"
        end
      end

      def sigexpr_to_als(se)
        @out.p @conf.sig_namer[se.__sig]
      end

      def unaryexpr_to_als(ue)
        op_str =
          case ue.op
          when TRANSPOSE, CLOSURE, RCLOSURE, CARDINALITY; ue.op.to_s
          else "#{ue.op} "
          end
        @out.p "#{op_str}#{enclose ue.op, ue.sub}"
      end

      def binaryexpr_to_als(be)
        fmt = case be.op
              when JOIN    then "%{lhs}.%{rhs}"
              when SELECT  then "%{lhs}[%{rhs}]"
              when IPLUS   then "plus[%{lhs}, %{rhs}]"
              when IMINUS  then "minus[%{lhs}, %{rhs}]"
              when MUL     then "mul[%{lhs}, %{rhs}]"
              when DIV     then "div[%{lhs}, %{rhs}]"
              when REM     then "rem[%{lhs}, %{rhs}]"
              when PRODUCT then "%{lhs} #{be.left_mult}#{be.op} %{rhs}"
              else
                "%{lhs} #{be.op} %{rhs}"
              end
        @out.p(fmt % {lhs: encloseL(be.op, be.lhs), rhs: encloseR(be.op, be.rhs)})
      end

      def callexpr_to_als(ce)
        pre = (ce.has_target?) ? "#{export_to_als ce.target}." : ""
        fun = case f=ce.fun
              when Arby::Ast::Fun; @conf.fun_namer[f]
              else f
              end
        args = ce.args.map(&method(:export_to_als)).join(", ")
        post = (args.empty?) ? "" : "[#{args}]"
        @out.p "#{pre}#{fun}#{post}"
      end

      def boolconst_to_als(bc)
        if bc.value
          ""
        else
          "1 != 0"
        end
      end

      def enclose(op, expr, rhs=false)
        e_str = export_to_als(expr)
        (expr.op.precedence < op.precedence) ||
          (rhs && expr.op.precedence == op.precedence) ? "(#{e_str})" : e_str
      end
      def encloseL(op, expr) enclose(op, expr, false) end
      def encloseR(op, expr) enclose(op, expr, true) end
    end

  end
end
