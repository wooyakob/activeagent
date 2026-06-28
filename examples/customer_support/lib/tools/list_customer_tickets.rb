# frozen_string_literal: true

require "ruby_llm"

# Lists all support tickets for a customer to surface full support history.
class ListCustomerTickets < RubyLLM::Tool
  description "List all past support tickets for a customer to understand their full support history."

  param :customer_id,
    type: "string",
    desc: "Customer ID (e.g. cust-001)"

  def initialize(store)
    @store = store
  end

  def execute(customer_id:)
    tickets = @store.find_tickets_for_customer(customer_id)

    return { found: false, message: "No ticket history for customer #{customer_id}" } if tickets.empty?

    {
      found:   true,
      total:   tickets.length,
      tickets: tickets.map do |t|
        {
          ticket_id:  t["id"],
          subject:    t["subject"],
          status:     t["status"],
          priority:   t["priority"],
          created_at: t["created_at"],
          updated_at: t["updated_at"]
        }
      end
    }
  end
end
