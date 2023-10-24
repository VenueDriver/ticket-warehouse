require_relative 'manager/ETL'
require_relative 'manager/Athena'
require_relative 'manager/Glue'

require 'dotenv'
Dotenv.load('.env')

module Manager
  class Core

    # Redo ETL.
    def self.ETL(time_range:'all', threads:4)
      puts "Resetting Ticket Warehouse..."

      puts "  Redoing ETL for time range: \"#{time_range}\"..."
      Manager::ETL.run(time_range:time_range, threads:threads)
    end

    # Crawl the data lake to create Athena tables.
    def self.crawl
      puts "Crawling data lake..."

      puts "  Starting Glue crawlers..."
      Manager::Glue.start_crawlers
    end

    # Redo ETL and recreate the Athena tables.
    def self.reset(threads:4)
      puts "Resetting Ticket Warehouse..."

      puts "  Redoing ETL for all time..."
      Manager::ETL.run(time_range:'all', threads:threads)

      puts "  Dropping Athena tables..."
      Manager::Athena.drop_tables

      puts "  Starting Glue crawlers..."
      Manager::Glue.start_crawlers
    end

  end
end
