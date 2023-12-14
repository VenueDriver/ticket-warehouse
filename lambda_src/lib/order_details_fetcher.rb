require 'concurrent'

class OrderDetailsFetcher
  attr_accessor :use_promises
  def initialize(ticketsauce_api:)
    @ticketsauce_api = ticketsauce_api
    @use_promises = true
  end

  def fetch_by_order_id_list(orders_id_list)
    task = Proc.new{|order_id| fetch_by_order_id(order_id)}
    if @use_promises
      orders_id_list.map do |order_id|
        #Concurrent::Promises.future(order_id, &task) uses the :io executor
        # which doesn't place any limits on the thread count
        # here we want a fixed number of threads to rate limit the requests
        Concurrent::Promises.future_on(:fast, order_id, &task)
      end.map{|future| future.value!  }
    else
      orders_id_list.map(&task)
    end
  end

  def fetch_with_positional_join(original_orders_list)
    orders_list = original_orders_list.dup
    orders_id_list = orders_list.map{|order| order['Order']['id'] }
    order_details_list = fetch_by_order_id_list(orders_id_list)

    orders_list.zip(order_details_list)
  end

  def fetch_by_order_id(order_id)
    @ticketsauce_api.fetch_api_data("https://api.ticketsauce.com/v2/order/#{order_id}")
  end

end

