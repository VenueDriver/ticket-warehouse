require 'concurrent'

class TicketWarehouse
  class Pool 
    def initialize(num_threads:4,using_threads:false)
      @pool = m_init_pool(num_threads)
      @using_threads = using_threads
    end

    def post( &block)
      if @using_threads
        @pool.post(&block)
      else
        block.call
      end
    end

    def kill
      @pool.kill
    end

    def m_init_pool(num_threads)
      pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: num_threads,
        max_threads: num_threads,
        max_queue: 0,
        fallback_policy: :caller_runs
      )
    end

    def shutdown_and_wait
      @pool.shutdown
      puts "Waiting for all threads to complete..."
      @pool.wait_for_termination
    end

    class << self
      def with_thread_pool(num_threads: 4, using_threads:false, &block)
        pool = self.new(num_threads:num_threads,using_threads:using_threads)
    
        block.call(pool)
    
        pool.shutdown_and_wait
      end
    end
  end
end