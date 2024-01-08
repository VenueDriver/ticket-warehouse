module Manifest
  module ReportVariants
    PRELIM = 'preliminary'
    FINAL = 'final'
    ACCOUNTING = 'accounting'
    
    module RenderDebug
      def render_mode   
        'debug'  
      end
    end
    
    module RenderStandard
      def render_mode   
        'standard'  
      end
    end
    
    module LabelFinal
      def label_mode
        "final"
      end
    end
    
    module LabelPrelim
      def label_mode
        "preliminary"
      end
    end

    module HasPdfAttachment
      def has_pdf?
        true
      end
    end

    module HasSurchargeCsvAttachment
      def has_surcharge_csv?
        true
      end
    end

    module HasFinalCsvAttachment
      def has_final_csv?
        true
      end
    end

    module ExcludePdfAttachment
      def has_pdf?
        false
      end
    end

    module ExcludeSurchargeCsvAttachment
      def has_surcharge_csv?
        false
      end
    end

    module ExcludeFinalCsvAttachment
      def has_final_csv?
        false
      end
    end

    class Base
      def preliminary?
        PRELIM == self.string_label
      end
      
      def final?
        FINAL == self.string_label
      end
      
      def accounting?
        ACCOUNTING == self.string_label
      end
      
      def show_warnings?
        self.render_mode == 'debug'
      end
      
      def label_as_final?
        self.label_mode == 'final'
      end

      def filename_prefix
        if self.label_as_final?
          return "FINAL"
        else
          return "PRELIMINARY"
        end
      end

      def has_pdf?
        raise 'Not implemented'
      end

      def has_surcharge_csv?
        raise 'Not implemented'
      end

      def has_final_csv?
        raise 'Not implemented'
      end
    end
    
    class Preliminary < Base
      include RenderDebug
      include LabelPrelim

      include HasPdfAttachment
      include HasSurchargeCsvAttachment
      include ExcludeFinalCsvAttachment
      
      def string_label; PRELIM ; end
    end
    
    class Final < Base
      include RenderStandard
      include LabelFinal

      include HasPdfAttachment
      include HasFinalCsvAttachment
      include ExcludeSurchargeCsvAttachment
      
      def string_label; FINAL ; end
    end
    
    class Accounting < Base
      include RenderDebug
      include LabelFinal

      include ExcludePdfAttachment
      include HasSurchargeCsvAttachment
      include ExcludeFinalCsvAttachment
      
      def string_label; ACCOUNTING ; end
    end
  end
end
