# A Thor CLI for managing the Ticket Warehouse.

require 'thor'
require_relative 'lib/quicksight'
require_relative 'lib/manager'
require_relative 'lambda_src/lib/manifest/manifest.rb'

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

    desc "daily", "Generate Daily Ticket Sale Report"
    def daily
      Manager::Core.daily
    end

    desc "manifest", "Run Manifest Report scheduling logic."
    def manifest
        event = {}

        # Global setting to switch on distro lists example
        #Manifest::Scheduling.use_distribution_list = true
        puts "Manifest::Scheduling.use_distribution_list: #{Manifest::Scheduling.use_distribution_list}"

        #env_in = 'production' #;ENV['ENV']
        env_in = ENV['ENV']
        manager = Manifest::Scheduling::Manager.create_from_lambda_input_event(event,env_in, ses_client:$ses_client)
        run_options = Manifest::Scheduling::Manager.create_run_options(event)

        r = manager.process_reports_using_now
    end

    desc "quickight", "Manage Quicksight resources."
    subcommand "quicksight", Quicksight

  end
end

Manager::CLI.start(ARGV)