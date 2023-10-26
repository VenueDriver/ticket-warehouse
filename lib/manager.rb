require_relative 'manager/load'
require_relative 'manager/Athena'
require_relative 'manager/Glue'

require 'dotenv'
Dotenv.load('.env')

module Manager
  class Core

    # Redo ETL.
    def self.Load(time_range:'all', threads:4)
      puts "Resetting Ticket Warehouse..."

      puts "  Reloading data for time range: \"#{time_range}\"..."
      Manager::Load.run(time_range:time_range, threads:threads)
    end

    # Crawl the data lake to create Athena tables.
    def self.crawl
      puts "Crawling data lake..."

      puts "  Starting Glue crawlers..."
      Manager::Glue.start_crawlers
    end

    # Reload data and recreate the Athena tables.
    def self.reset(threads:4)
      puts "Resetting Ticket Warehouse..."

      puts "  Reloading data for all time..."
      Manager::Load.run(time_range:'all', threads:threads)

      puts "  Dropping Athena tables..."
      Manager::Athena.drop_tables

      puts "  Starting Glue crawlers..."
      Manager::Glue.start_crawlers
    end

  end
end
