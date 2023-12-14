module Manager
  class Quicksight < Thor

    desc "purge", "Remove all Quicksight resources."
    def purge
      Manager::Quicksight.purge()
    end

    desc "source", "Create Quicksight data source."
    def sources
      Manager::Quicksight.source()
    end

    desc "datasets", "Create Quicksight dataset."
    def datasets
      Manager::Quicksight.datasets()
    end

  end
end