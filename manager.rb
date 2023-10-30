# A Thor CLI for managing the Ticket Warehouse.

require 'thor'
require_relative 'lib/quicksight'
require_relative 'lib/manager'

module Manager
  class CLI < Thor

    desc "purge", "Purge the S3 bucket and remove the Athena tables."
    def purge
      Manager::Core.purge(time_range:options[:time_range], threads:options[:threads])
    end

    desc "load", "Load data from Ticketsauce to the data lake S3 bucket."
    option :time_range, :type => :string, :default => 'all', :desc => "The time range to reload data for. Valid values are 'all', 'current', 'upcoming'."
    option :threads, :type => :numeric, :default => 4, :desc => "The number of threads to use for loading data.  Default is 4."
    def load
      Manager::Core.load(time_range:options[:time_range], threads:options[:threads])
    end

    desc "crawl", "Run Glue crawlers on the data in the data lake S3 bucket to create Athena tables."
    def crawl
      Manager::Core.crawl
    end

    desc "reset", "Redo ETL and recreate the Athena tables."
    option :time_range, :type => :string, :default => 'all', :desc => "The time range to redo ETL for. Valid values are 'all', 'current', 'upcoming'."
    option :threads, :type => :numeric, :default => 4, :desc => "The number of threads to use for ETL.  Default is 4."
    def reset
      Manager::Core.reset(time_range:options[:time_range], threads:options[:threads])
    end

    desc "qs", "Manage Quicksight resources."
    subcommand "qs", Quicksight

  end
end

Manager::CLI.start(ARGV)