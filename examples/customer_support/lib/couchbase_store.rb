# frozen_string_literal: true

require "couchbase"
require "securerandom"
require "time"

# Manages Couchbase connectivity and all data operations for the support agent.
# Uses named collections within the _default scope for clean data organization:
#   customers, orders, tickets, knowledge_base
class CouchbaseStore
  BUCKET_NAME = ENV.fetch("COUCHBASE_BUCKET", "customer_support").freeze

  def initialize
    options = Couchbase::Options::Cluster.new
    options.authenticate(
      ENV.fetch("COUCHBASE_USERNAME", "Administrator"),
      ENV.fetch("COUCHBASE_PASSWORD", "password")
    )
    @cluster = Couchbase::Cluster.connect(
      ENV.fetch("COUCHBASE_CONNECTION_STRING", "couchbase://localhost"),
      options
    )
    @bucket = @cluster.bucket(BUCKET_NAME)
  end

  # ---- Customer lookups ----

  def find_customer_by_email(email)
    n1ql(
      "SELECT id, name, email, phone, tier, created_at, total_orders, lifetime_value " \
      "FROM `#{BUCKET_NAME}`.`_default`.`customers` " \
      "WHERE email = $email LIMIT 1",
      email: email
    ).first
  end

  def find_customer_by_id(customer_id)
    collection("customers").get(customer_id).content
  rescue Couchbase::Error::DocumentNotFound
    nil
  end

  # ---- Order lookups ----

  def find_order_by_id(order_id)
    collection("orders").get(order_id).content
  rescue Couchbase::Error::DocumentNotFound
    nil
  end

  def find_orders_for_customer(customer_id, limit: 5)
    n1ql(
      "SELECT id, status, items, total, created_at, shipped_at, " \
      "tracking_number, carrier, estimated_delivery " \
      "FROM `#{BUCKET_NAME}`.`_default`.`orders` " \
      "WHERE customer_id = $customer_id " \
      "ORDER BY created_at DESC LIMIT #{limit.to_i}",
      customer_id: customer_id
    )
  end

  # ---- Ticket operations ----

  def find_ticket_by_id(ticket_id)
    collection("tickets").get(ticket_id).content
  rescue Couchbase::Error::DocumentNotFound
    nil
  end

  def find_tickets_for_customer(customer_id)
    n1ql(
      "SELECT id, subject, status, priority, created_at, updated_at " \
      "FROM `#{BUCKET_NAME}`.`_default`.`tickets` " \
      "WHERE customer_id = $customer_id " \
      "ORDER BY created_at DESC",
      customer_id: customer_id
    )
  end

  def create_ticket(customer_id:, subject:, description:, priority: "normal")
    ticket_id = "tkt-#{SecureRandom.hex(4)}"
    now = Time.now.utc.iso8601

    ticket = {
      "id"          => ticket_id,
      "customer_id" => customer_id,
      "subject"     => subject,
      "description" => description,
      "status"      => "open",
      "priority"    => priority,
      "created_at"  => now,
      "updated_at"  => now,
      "messages"    => [
        { "role" => "customer", "content" => description, "timestamp" => now }
      ]
    }

    collection("tickets").upsert(ticket_id, ticket)
    ticket
  end

  def update_ticket(ticket_id:, status: nil, priority: nil, agent_note: nil)
    col    = collection("tickets")
    ticket = col.get(ticket_id).content

    ticket["status"]     = status   if status
    ticket["priority"]   = priority if priority
    ticket["updated_at"] = Time.now.utc.iso8601

    if agent_note
      ticket["messages"] ||= []
      ticket["messages"] << {
        "role"      => "agent",
        "content"   => agent_note,
        "timestamp" => Time.now.utc.iso8601
      }
    end

    col.upsert(ticket_id, ticket)
    ticket
  rescue Couchbase::Error::DocumentNotFound
    nil
  end

  # ---- Knowledge base search ----

  def search_knowledge_base(query_text, limit: 3)
    pattern = "%#{query_text.downcase}%"
    n1ql(
      "SELECT id, title, content, tags, helpful_votes " \
      "FROM `#{BUCKET_NAME}`.`_default`.`knowledge_base` " \
      "WHERE LOWER(title) LIKE $pattern OR LOWER(content) LIKE $pattern " \
      "ORDER BY helpful_votes DESC " \
      "LIMIT #{limit.to_i}",
      pattern: pattern
    )
  end

  def disconnect
    @cluster.disconnect
  end

  private

  def collection(name)
    @bucket.default_scope.collection(name)
  end

  def n1ql(statement, **named_params)
    options = Couchbase::Options::Query.new
    options.named_parameters(named_params) unless named_params.empty?
    @cluster.query(statement, options).rows
  end
end
