require 'benchmark'
require 'sdg_utils/print_utils/tree_printer.rb'

module SDGUtils
  module Timing

    class Timer

      class Node
        attr_reader :task, :task_param, :children, :parent, :props
        attr_accessor :time
        def initialize(task, task_param=nil, parent=nil, props={})
          @task = task
          @task_param = task_param
          @parent = parent
          @children = []
          @props = props
          @last_node = nil
          parent.children << self if parent
        end

        def time() @time || 0 end
      end

      def initialize
        @stack = []
        @root = Node.new("ROOT")

        @tree_printer = SDGUtils::PrintUtils::TreePrinter.new({
          :indent_size => 2,
          :print_root  => false,
          :printer     => lambda {|n| "#{n.task}(#{n.task_param}): #{n.time * 1000}ms"},
          :descender   => lambda {|n| n.children + unaccounted(n)},
        })
      end

      def unaccounted(node)
        return [] if node.time.nil? || node.children.empty?
        ans = Node.new("*** Unaccounted time ***", nil, nil, :unaccounted_for => node)
        ans.time = node.time - node.children.reduce(0){|acc, ch| acc + ch.time}
        [ans]
      end

      def time_it(task="<unspecified>", task_param=nil, &block)
        parent = @stack.last || @root
        node = Node.new(task, task_param, parent)
        begin
          @stack.push node
          ans = nil
          node.time = Benchmark.realtime{ans = yield}
          ans
        ensure
          @last_node = @stack.pop
        end
      end

      def last_time() @last_node and @last_node.time end

      def print
        @tree_printer.print_tree(@root)
      end

      def summary
        sum = {}
        cnt = {}
        add_time = lambda{|task, time|
          task = task.split("\n").first
          task_time = sum[task] || 0
          sum[task] = task_time + time
          task_cnt  = cnt[task] || 0
          cnt[task] = task_cnt + 1
        }
        @tree_printer.traverse(@root) do |node|
          if n=node.props[:unaccounted_for]
            add_time.call("#{n.task} (unaccounted)", node.time)
          elsif node.children.empty?
            add_time.call(node.task, node.time)
          else
            add_time.call("#{node.task} (total)", node.time)
          end
        end
        ans = {}
        sum.each{|key, time| ans[key] = [time, cnt[key]]}
        ans
      end
    end

  end
end
