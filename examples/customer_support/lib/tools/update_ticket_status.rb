# frozen_string_literal: true

require "ruby_llm"

# Updates an existing support ticket's status, priority, or appends a note.
class UpdateTicketStatus < RubyLLM::Tool
  description "Update an existing support ticket's status, priority, or add an agent note."

  param :ticket_id,
    type: "string",
    desc: "Ticket ID to update (e.g. tkt-0001)"

  param :status,
    type: "string",
    desc: "New status: 'open', 'in_progress', 'waiting_customer', 'resolved', or 'closed'",
    required: false

  param :priority,
    type: "string",
    desc: "New priority: 'low', 'normal', 'high', or 'urgent'",
    required: false

  param :agent_note,
    type: "string",
    desc: "Note to append to the ticket thread",
    required: false

  def initialize(store)
    @store = store
  end

  def execute(ticket_id:, status: nil, priority: nil, agent_note: nil)
    ticket = @store.update_ticket(
      ticket_id:  ticket_id,
      status:     status,
      priority:   priority,
      agent_note: agent_note
    )

    return { success: false, error: "Ticket #{ticket_id} not found" } unless ticket

    {
      success:    true,
      ticket_id:  ticket["id"],
      status:     ticket["status"],
      priority:   ticket["priority"],
      updated_at: ticket["updated_at"]
    }
  end
end
