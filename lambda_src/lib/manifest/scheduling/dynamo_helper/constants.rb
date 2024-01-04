
module Manifest
  class Scheduling
    DEFAULT_DDB_TABLE_NAME = 'manifest_delivery_control-production'
    DEFAULT_DDB_PREFIX = 'manifest_delivery_control'

    CONTROL_INITIALIZED = 'initialized'
    PRELIM_SENT = 'prelim_sent'
    REPORT_CANCELED = 'report_canceled'
    FINAL_SENT = 'final_sent'
    CONTROL_ROW_DOES_NOT_EXIST = 'control_row_does_not_exist'
  
    VALID_REPORT_STATUSES = [CONTROL_INITIALIZED, PRELIM_SENT, REPORT_CANCELED, FINAL_SENT]
  
  end
end


