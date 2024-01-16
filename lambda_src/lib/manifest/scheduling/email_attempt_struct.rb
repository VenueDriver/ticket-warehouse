module Manifest
  class Scheduling
    class ReportPerformer

      EmailAttempt = Struct.new(
        :email_was_sent, 
        :ses_raw_email_result,
        :error_message, 
        :error_class, 
        :error_object,
        keyword_init:true ) do
          def self.success(ses_raw_email_result)
            self.new(email_was_sent:true, ses_raw_email_result:ses_raw_email_result)
          end
  
          def self.failure(exception_object)
            # exception_object is an instance of StandardError
            self.new(
              email_was_sent:false,
              error_message:exception_object.message,
              error_class:exception_object.class.name,
              error_object:exception_object
            )
          end

          def succeeded?
            self.email_was_sent
          end

          def failed?
            !self.succeeded?
          end

          def self.perform!(&block_that_tries_to_email)
            ses_raw_email_result = block_that_tries_to_email.call
            self.success(ses_raw_email_result)
          rescue StandardError => e
            puts "ERROR: #{e.message}"
            # replace with "raise e" if you want to 
            # allow the exception to bubble up
            self.failure(e)           
          end
        end

    end
  end
end