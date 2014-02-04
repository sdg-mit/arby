module SDGUtils
  module PrintUtils

    class TreeVisitor
      def initialize(hash={})
        @descender = hash[:descender] || lambda{|node| node.children}
      end

      def traverse(tree, &block)
        yield(tree)
        @descender.call(tree).each do |child|
          traverse(child, &block)
        end
      end
    end

    class TreePrinter

      def initialize(hash={})
        @indent_size  = hash[:indent_size]  || 2
        @printer      = hash[:printer]      || lambda{|node| node.to_s}
        @descender    = hash[:descender]    || lambda{|node| node.children}
        @print_root   = hash.key?(:print_root) ? hash[:print_root] : true
        @children_sep = hash[:children_sep] || ""
        @line_prepend = hash[:line_prepend]
        @line_append  = hash[:line_append]
        @max_line     = hash[:max_line]
        @box          = read_box(hash[:box])
        @tab0         = hash[:tab0] || " "
        @tab1         = hash[:tab1] || "|"
        @tab2         = hash[:tab2] || "`"

        @indent_size.times {
          @tab0.concat " ";
          @tab1.concat " ";
          @tab2.concat "-"
        }
      end

      def traverse(node, &block)
        tv = TreeVisitor.new :descender => @descender
        tv.traverse(node, &block)
      end

      def print_tree(node, depth=0, __depth=0)
        node_out = ""
        unless __depth == 0 && !@print_root
          node_out = print_node(node, depth)
        end
        @descender.call(node).reduce(node_out) { |acc, child|
          acc.concat(@children_sep).concat(print_tree(child, depth+1, __depth+1))
        }
      end

      def print_node(node, depth=0)
        node_str = @printer.call(node)
        lines = (Array === node_str ? node_str : node_str.split("\n"))

        prepend_append_lines(lines, @line_prepend, @line_append)

        if @max_line
          set_line_size(lines, @max_line)
        end

        box_top = box_bottom = nil
        if @box
          width = box_width(@box, lines)
          box_top = make_border(width, @box[:top_left], @box[:top], @box[:top_right])
          box_bottom = make_border(width, @box[:bottom_left],
                                   @box[:bottom], @box[:bottom_right])
          left = @box[:left] + padding(@box[:padding_left])
          right = padding(@box[:padding_right]) + @box[:right]
          set_line_size(lines, width - left.length - right.length)
          prepend_append_lines(lines, left, right)
        end

        lines.unshift box_top if box_top
        lines.push box_bottom if box_bottom

        ind_fst = indent(depth)
        ind_rest = indent(depth, @tab1, @tab0)
        idx = -1
        node_out = lines.reduce("") { |acc, line|
          idx += 1
          acc.concat(idx == 0 ? ind_fst : ind_rest)
            .concat(line)
            .concat("\n")
        }
      end

      private

      def indent(depth, t1=@tab1, t2=@tab2)
        (0...depth-1).reduce("") {|acc,i| acc.concat(i == depth-2 ? t2 : t1)}
      end

      def read_box(opts)
        case opts
        when NilClass
          nil
        when FalseClass
          nil
        when TrueClass
          default_box
        when Hash
          default_box.merge(opts)
        end
      end

      def box_width(box, lines)
        width = box[:width]
        case width
        when Integer
          width
        when :tight
          line_max = lines.max_by{|line| line.length}.length
          line_max + box[:left].length + box[:right].length +
                     box[:padding_left] + box[:padding_right]
        else
          fail "Unrecognized box width option: #{width}:#{width.class}"
        end
      end

      def make_border(width, left_corner, center, right_corner)
        center_width = width - left_corner.length - right_corner.length
        center_num = center_width/center.length
        center_line = ""
        center_num.times{center_line.concat center}
        rem = center_width - center_line.length
        center_line.concat center[0...rem]
        "#{left_corner}#{center_line}#{right_corner}"
      end

      def set_line_size(line, size)
        case line
        when Array
          line.each{|l| set_line_size(l, size)}
        else
          if line.length > size
            line[size..-1] = ''
          else
            (size - line.length).times{line.concat " "}
          end
          fail "DLFSKJ" unless line.length == size
        end
      end

      def prepend_append_lines(lines, pre, post)
        if pre || post
          left = pre || ""
          right = post || ""
          lines.each { |line|
            line.insert(0, left)
            line.concat(right)
          }
        end
      end

      def padding(size, char=" ")
        ans = ""
        size.times{ans.concat char}
        ans
      end

      def default_box
        @def_box ||= {
          :width => :tight,
          :top => "-",
          :bottom => "-",
          :left => "|",
          :right => "|",
          :top_left => "+",     # "\xC9",
          :top_right => "+",    #"\xBB",
          :bottom_left => "+",  # "\xC8",
          :bottom_right => "+", #"\xBC",
          :padding_left => 1,
          :padding_right => 1,
          :padding_top => 0,
          :padding_bottom => 0,
        }
      end

    end

  end
end
