require 'ostruct'

module SDGUtils
  module PrintUtils

    class CodePrinter

      def initialize(options={})
        def_opts = {
          :visitor      => nil,
          :visit_method => :visit,
          :tab          => "  ",
        }
        @conf       = OpenStruct.new def_opts.merge!(options)
        @visit_meth = @conf.visitor ? @conf.visitor.method(@conf.visit_method) : nil
        @out        = ""
        @depth      = 0
        @indent     = ""
      end

      def concat(str, split_sep="\n")
        str = str.to_s
        lines = (split_sep.nil?) ? [str] : str.split(split_sep)
        print_array(lines, split_sep, false)
        self
      end

      alias_method :p, :concat

      def print_line(str="")
        concat(str)
        new_line
        self
      end

      alias_method :pl, :print_line

      def new_line
        @out << "\n"
        self
      end

      alias_method :nl, :new_line

      def print_array(ary, join_sep="", split_each_elem=false, split_sep="\n")
        dont_split = @indent.empty? || !split_each_elem
        ary.each_with_index do |str, idx|
          @out << join_sep unless idx == 0
          if dont_split
            @out << @indent << str
          else
            concat(str, split_sep)
          end
        end
        self
      end

      alias_method :pa, :print_array

      def indent
        inc_indent
        update_indent
        yield
      ensure
        dec_indent
      end

      alias_method :in, :indent

      def print_nodes(nodes, join_sep="", split_each_node=true, split_sep="\n")
        str = nodes.map(&@visit_meth)
        print_array str, join_sep, split_each_node, split_sep
        self
      end

      alias_method :pn, :print_nodes

      def to_s
        @out.dup
      end

      def depth() @depth end
      def indent() @indent end
      def tab() @conf.tab end

      protected

      def inc_indent()
        @depth += 1
        update_indent()
      end

      def dec_indent()
        @depth -= 1
        update_indent()
      end

      def update_indent()
        @indent = (0...@depth).reduce(""){|acc,_| acc.concat(@conf.tab)}
      end

    end

  end
end
