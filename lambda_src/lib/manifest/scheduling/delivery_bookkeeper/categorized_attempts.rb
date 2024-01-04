module Manifest
  class Scheduling
    class DeliveryBookkeeper

      CategorizedAttempts = Struct.new(
        :preliminary_succeeded ,
        :preliminary_failed ,
        :final_succeeded ,
        :final_failed,
        keyword_init: true
      ) 

    end
  end
end