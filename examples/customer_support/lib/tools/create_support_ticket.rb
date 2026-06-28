# frozen_string_literal: true

require "ruby_llm"

# Creates a new support ticket for issues requiring follow-up.
class CreateSupportTicket < RubyLLM::Tool
  description "Create a support ticket for issues that need follow-up or escalation. " \
              "Use after attempting resolution via the knowledge base. Requires customer_id."

  param :customer_id,
    type: "string",
    desc: "Customer ID from lookup (e.g. cust-001)"

  param :subject,
    type: "string",
    desc: "Brief summary of the issue (e.g. 'Missing item from order ord-1001')"

  param :description,
    type: "string",
    desc: "Full details of the issue including relevant order or product information"

  param :priority,
    type: "string",
    desc: "Urgency: 'low', 'normal', 'high', or 'urgent' (default: 'normal')",
    required: false

  def initialize(store)
    @store = store
  end

  def execute(customer_id:, subject:, description:, priority: "normal")
    priority = "normal" unless %w[low normal high urgent].include?(priority.to_s)

    ticket = @store.create_ticket(
      customer_id: customer_id,
      subject:     subject,
      description: description,
      priority:    priority
    )

    {
      success:      true,
      ticket_id:    ticket["id"],
      subject:      ticket["subject"],
      status:       ticket["status"],
      priority:     ticket["priority"],
      created_at:   ticket["created_at"],
      confirmation: "Ticket #{ticket['id']} created. Our team will follow up within 24 hours."
    }
  end
end
