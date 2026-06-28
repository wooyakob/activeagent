# frozen_string_literal: true

require "ruby_llm"
require_relative "couchbase_store"
require_relative "tools/lookup_customer"
require_relative "tools/get_order_status"
require_relative "tools/search_knowledge_base"
require_relative "tools/create_support_ticket"
require_relative "tools/update_ticket_status"
require_relative "tools/list_customer_tickets"

# Orchestrates the customer support conversation using Claude + Couchbase-backed tools.
# RubyLLM.configure must be called before instantiating this class.
class SupportAgent
  SYSTEM_PROMPT = <<~PROMPT
    You are a friendly, empathetic customer support agent for Acme Store, an online retailer.
    Your goal is to resolve customer issues efficiently while delivering an excellent experience.

    ## Your Tools
    You have real-time access to customer data through these tools:
    - **lookup_customer** – Find a customer by email or ID; call this immediately when given contact info
    - **get_order_status** – Check order details, shipping status, and tracking
    - **search_knowledge_base** – Find relevant help articles and policies
    - **list_customer_tickets** – View a customer's full support ticket history
    - **create_support_ticket** – Open a ticket for issues needing follow-up
    - **update_ticket_status** – Change ticket status, priority, or add a note

    ## Workflow Guidelines
    1. **Identify first** – When a customer shares email or ID, immediately call lookup_customer
    2. **Check context** – For order questions, call get_order_status; for history, call list_customer_tickets
    3. **Search before escalating** – Use search_knowledge_base before creating a ticket
    4. **Escalate when needed** – Create a ticket for any issue that can't be resolved in this conversation
    5. **Acknowledge emotions** – If a customer is frustrated, validate their feelings before problem-solving
    6. **Confirm resolution** – Always verify the issue is resolved before closing the conversation

    ## Tone
    - Warm, professional, and conversational
    - Clear and jargon-free
    - Especially empathetic for delivery delays, damaged items, or billing disputes

    When in doubt, create a ticket — it's better to over-document than to let an issue fall through.
  PROMPT

  def initialize
    @store = CouchbaseStore.new
    @chat  = build_chat
  end

  def ask(message)
    @chat.ask(message)
  end

  def disconnect
    @store.disconnect
  end

  private

  def build_chat
    RubyLLM
      .chat(model: ENV.fetch("CLAUDE_MODEL", "claude-3-5-haiku-20241022"))
      .with_instructions(SYSTEM_PROMPT)
      .with_tools(
        LookupCustomer.new(@store),
        GetOrderStatus.new(@store),
        SearchKnowledgeBase.new(@store),
        CreateSupportTicket.new(@store),
        UpdateTicketStatus.new(@store),
        ListCustomerTickets.new(@store)
      )
  end
end
