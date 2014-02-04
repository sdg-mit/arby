module Arby
  module Helpers
    module Test

      class TestEventListener
        attr_reader :read, :written

        def initialize()
          @read = []
          @written = []
        end

        def call(event, hash)
          case event
          when :field_read
            @read << hash
          when :field_written
            @written << hash
          end
        end

        def format_reads
          @read.map { |e| "#{e[:object]}.#{e[:field].name} -> #{e[:return].inspect}" }
        end

        def format_writes
          @written.map { |e| "#{e[:object]}.#{e[:field].name} <- #{e[:value].inspect}" }
        end
      end

    end
  end
end
