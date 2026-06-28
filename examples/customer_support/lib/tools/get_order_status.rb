# frozen_string_literal: true

require "ruby_llm"

# Retrieves order details by order ID or lists recent orders for a customer.
class GetOrderStatus < RubyLLM::Tool
  description "Get the status and details of a specific order, or list a customer's recent orders."

  param :order_id,
    type: "string",
    desc: "Specific order ID (e.g. ord-1001). Provide this OR customer_id, not both.",
    required: false

  param :customer_id,
    type: "string",
    desc: "Customer ID to list their recent orders. Provide this OR order_id, not both.",
    required: false

  def initialize(store)
    @store = store
  end

  def execute(order_id: nil, customer_id: nil)
    if order_id && !order_id.empty?
      fetch_single_order(order_id)
    elsif customer_id && !customer_id.empty?
      fetch_customer_orders(customer_id)
    else
      { error: "Provide either order_id or customer_id" }
    end
  end

  private

  def fetch_single_order(order_id)
    order = @store.find_order_by_id(order_id)
    return { found: false, message: "Order #{order_id} not found" } unless order

    { found: true, order: format_order(order) }
  end

  def fetch_customer_orders(customer_id)
    orders = @store.find_orders_for_customer(customer_id)
    return { found: false, message: "No orders found for customer #{customer_id}" } if orders.empty?

    { found: true, orders: orders.map { |o| format_order(o) } }
  end

  def format_order(order)
    {
      order_id:            order["id"],
      status:              order["status"],
      items:               order["items"],
      total:               order["total"],
      placed_on:           order["created_at"],
      shipped_on:          order["shipped_at"],
      carrier:             order["carrier"],
      tracking_number:     order["tracking_number"],
      estimated_delivery:  order["estimated_delivery"]
    }
  end
end
