require 'arby/bridge/imports'
require 'arby/bridge/solution'
require 'sdg_utils/random'
require 'sdg_utils/timing/timer'

module Arby
  module Bridge
    class Compiler
      # @model     [Arby::Ast::Model]
      # @bounds    [Arby::Ast::Bounds]
      def self.compile(model, bounds=nil)
        compiler = Compiler.new(model, bounds)
        compiler.send :_parse
        compiler
      end

      def self.solve(model, pred, scope, bounds=nil)
        sc = scope.extend_for_bounds(bounds)
        Compiler.new(model, bounds).solve(pred, sc)
      end

      def self.execute_command(model, cmd_idx_or_name=0, bounds=nil)
        Compiler.new(model, bounds).execute_command(cmd_idx_or_name)
      end

      def model()     @model end
      def univ()      @univ end
      def _a4world()  @a4world end

      # @see Compiler.all_fields
      def all_fields
        fail_if_not_parsed
        AlloyCompiler.all_fields(@a4world)
      end

      def solve(pred, scope)
        cmd_name, cmd_body =
          pred ? [pred, ""]
               : ["find_model_#{SDGUtils::Random.salted_timestamp}", "{}"]
        cmd_als = "run #{cmd_name} #{cmd_body} #{scope.to_als}"

        sol = _execute(_parse(cmd_als), -1)
        sol.set_solving_params :solve, pred, scope
        sol
      end

      # @see Compiler.execute_command
      # @result [Arby::Bridge::Solution]
      def execute_command(cmd_idx_or_name=0)
        sol = _execute(_parse(), cmd_idx_or_name)
        sol.set_solving_params :execute_command, cmd_idx_or_name
        sol
      end

      def initialize(model, bounds=nil)
        @model     = model
        @bounds    = bounds
        @univ      = bounds ? bounds.extract_universe : nil
        @rep       = nil # we don't care to listen to reports
        @timer     = SDGUtils::Timing::Timer.new

        if model && @bounds
          __pi_atoms = @bounds.each_lower.map{ |what, ts|
            if Arby::Ast::TypeChecker.check_sig_class(what)
              fail unless ts.arity == 1
              ts.tuples.map{|t| t.atom(0)}
            end
          }.compact.flatten(1).reject{|a| model.find_pi_sig_for_atom(a)}
          unless __pi_atoms.empty?
            @model = model.extend do
              __pi_atoms.each do |a|
                one sig(Arby.short_alloy_printer_conf.atom_sig_namer[
                          a.class.relative_name, a.__alloy_atom_id] < a.class) do
                  set_atom(a.__alloy_atom_id)
                end
              end
            end
          end
        end
      end

      private

      # @see Compiler.execute_command
      # @result [Arby::Bridge::Solution]
      def _execute(a4wrld, cmd_idx_or_name=0)
        pi = @bounds && @bounds.serialize(@univ)

        a4sol = @timer.time_it("execute_command") {
          AlloyCompiler.execute_command(a4wrld, cmd_idx_or_name, pi)
        }
        sol = Solution.new(a4sol, self, @univ, @bounds, @timer.last_time)
        sol.arby_instance if @univ && !@univ.sig_atoms.empty?
        sol
      end


      # @see Compiler.parse
      def _parse(addendum="")
        # fail "already parsed" if @a4world
        fail "als model not set" unless @model
        als = @model.to_als + "\n" + addendum

        # puts "parsing this"
        # puts als
        # puts "--------------------------"

        @a4world = AlloyCompiler.parse(als)
      end

      def fail_if_not_parsed
        fail "model not parsed; call `parse' first" unless @a4world
      end
    end

    module AlloyCompiler
      extend self

      # =================================================================
      # Static, functional-style API (no state carried around)
      # =================================================================
      include Imports
      extend Imports

      # Takes an Alloy model (in Alloy's native als format), parses it
      # into Alloy's native ast form and returns the result.
      #
      # @param als_model [String]
      # @return [Rjb::Proxy ~> CompModule]
      def parse(als_model)
        catch_alloy_errors{ CompUtil_RJB.parseEverything_fromString(@rep, als_model) }
      end

      # Takes a proxy to an Alloy module and an index of a command to
      # execute; executes that command and returns a proxy to an
      # A4Solution object.
      #
      # @param a4world [Rjb::Proxy ~> CompModule]
      # @param cmd_idx_or_name [Int, String] - index or name of the command to execute
      # @param partialInstanceStr [String] - partial instance in a serialized format
      # @return [Rjb::Proxy ~> A4Solution]
      def execute_command(a4world, cmd_idx_or_name=0, partialInstanceStr=nil)
        command_index = case cmd_idx_or_name
                        when Integer
                          cmd_idx_or_name
                        when Symbol, String
                          find_cmd_idx_by_name!(a4world, cmd_idx_or_name)
                        else fail "wrong command type: expected Integer or String, " +
                                  "got #{cmd_idx_or_name}:#{cmd_idx_or_name.class}"
                        end
        commands = a4world.getAllCommands()
        command_index = commands.size + command_index if command_index < 0
        cmd = commands.get(command_index)
        opt = A4Options_RJB.new
        opt.solver = opt.solver.SAT4J #SAT4J #MiniSatJNI
        opt.renameAtoms = false
        opt.partialInstance = partialInstanceStr

        # puts "using command index--"
        # puts command_index
        # puts "---------------------"

        # puts "using bounds---------"
        # puts partialInstanceStr.inspect
        # puts "---------------------"
        # puts partialInstanceStr

        catch_alloy_errors {
          sigs = a4world.getAllReachableSigs
          TranslateAlloyToKodkod_RJB.execute_command @rep, sigs, cmd, opt
        }
      end

      # Takes a proxy to an Alloy module and returns a flat list of
      # Alloy fields.
      #
      # @param a4world [Rjb::Proxy ~> CompModule]
      # @return [Array(Rjb::Proxy ~> Sig$Field)]
      def all_fields(a4world)
        a4sigs = a4world.getAllReachableSigs
        alloy_fields = []
        num_sigs = a4sigs.size()
        for i in 0...num_sigs
          a4fields = a4sigs.get(i).getFields
          num_fields = a4fields.size
          for i in 0...num_fields
            alloy_fields.push(a4fields.get(i))
          end
        end
        return alloy_fields
        # (0...a4sigs.size).map{ |sig_idx|
        #   a4fields = a4sigs.get(sig_idx).getFields
        #   (0...a4fields.size).map{ |fld_idx|
        #     a4fields.get(fld_idx)
        #   }
        # }.flatten
      end

      def find_cmd_idx_by_name(a4world, cmd_name)
        commands = a4world.getAllCommands
        num_commands = commands.size
        for i in (0...num_commands).to_a.reverse
          return i if cmd_str = commands.get(i).label == cmd_name.to_s
        end
        -1
      end

      def find_cmd_idx_by_name!(a4world, cmd_name)
        idx = find_cmd_idx_by_name(a4world, cmd_name)
        fail "command #{cmd_name} not found" if idx == -1
        idx
      end
    end
  end
end

