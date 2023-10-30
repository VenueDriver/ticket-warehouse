module Manager
  class Quicksight < Thor

    desc "sources", "Create Quicksight data sources."
    def sources
      Manager::Quicksight.sources()
    end

    desc "datasets", "Create Quicksight dataset."
    def datasets
      Manager::Quicksight.datasets()
    end

  end
end