# frozen_string_literal: true

require "ruby_llm"

# Finds a customer account by email address or customer ID.
# Always call this first when the customer shares their contact information.
class LookupCustomer < RubyLLM::Tool
  description "Look up a customer's account by email address or customer ID. " \
              "Call this as soon as the customer shares any identifying information."

  param :identifier,
    type: "string",
    desc: "Customer email (e.g. jane@example.com) or customer ID (e.g. cust-001)"

  def initialize(store)
    @store = store
  end

  def execute(identifier:)
    customer = if identifier.include?("@")
      @store.find_customer_by_email(identifier)
    else
      @store.find_customer_by_id(identifier)
    end

    return { found: false, message: "No customer found with: #{identifier}" } unless customer

    {
      found:          true,
      customer_id:    customer["id"],
      name:           customer["name"],
      email:          customer["email"],
      phone:          customer["phone"],
      tier:           customer["tier"],
      member_since:   customer["created_at"],
      total_orders:   customer["total_orders"],
      lifetime_value: customer["lifetime_value"]
    }
  end
end
