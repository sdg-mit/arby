require 'active_record'
require 'generators/red/migrate/migrate_generator'

module SDGUtils
  module DB

    module DBHelpers
      class Mig < ActiveRecord::Migration
        def drop_db(conn)
          conn.tables.each do |t|
            drop_table t
          end
        end
      end

      def db_setup
        conf = YAML.load(File.read('config/database.yml'))
        ActiveRecord::Base.establish_connection(conf["test"])
        @conn = ActiveRecord::Base.connection
      end

      def db_drop(conn=@conn)
        Mig.new.drop_db(conn)
      end
    end

  end
end