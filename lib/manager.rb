require_relative 'manager/load'
require_relative 'manager/Athena'
require_relative 'manager/Glue'
require_relative 'manager/S3'
require_relative 'manager/Quicksight'
require_relative '../lambda_src/lib/report'

require 'dotenv'
Dotenv.load('.env')

module Manager
  class Core

    # Purge the S3 bucket and remove the Athena tables.
    def self.purge(time_range:'all', threads:4)
      Manager::S3.purge_bucket
      Manager::Athena.drop_tables
    end

    # Reload dat from Ticketsauce.
    def self.load(time_range:'all', threads:4)
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

    # Generate Daily Ticket Sales Report
    def self.daily
      Report::Daily.new.generate
    end

  end
end
