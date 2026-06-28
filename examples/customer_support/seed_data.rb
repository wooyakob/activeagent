#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Seed script: creates collections and loads sample data into Couchbase.
# Run once before starting the chat agent:
#   bundle exec ruby seed_data.rb

require "dotenv/load"
require "couchbase"

BUCKET_NAME = ENV.fetch("COUCHBASE_BUCKET", "customer_support")
COLLECTIONS = %w[customers orders tickets knowledge_base].freeze

# ---- Connect ----------------------------------------------------------------
puts "Connecting to Couchbase at #{ENV.fetch('COUCHBASE_CONNECTION_STRING', 'couchbase://localhost')}..."

cluster_options = Couchbase::Options::Cluster.new
cluster_options.authenticate(
  ENV.fetch("COUCHBASE_USERNAME", "Administrator"),
  ENV.fetch("COUCHBASE_PASSWORD", "password")
)
cluster = Couchbase::Cluster.connect(
  ENV.fetch("COUCHBASE_CONNECTION_STRING", "couchbase://localhost"),
  cluster_options
)
bucket = cluster.bucket(BUCKET_NAME)

# ---- Create collections -----------------------------------------------------
puts "\nCreating collections in '#{BUCKET_NAME}'..."
COLLECTIONS.each do |coll_name|
  spec = Couchbase::Management::CollectionSpec.new
  spec.scope_name = "_default"
  spec.name = coll_name
  bucket.collections.create_collection(spec)
  puts "  ✓ Created: #{coll_name}"
rescue Couchbase::Error::CollectionAlreadyExists
  puts "  - Exists:  #{coll_name}"
end

puts "  Waiting for collections to be ready..."
sleep 3

# ---- Create query indexes ---------------------------------------------------
puts "\nCreating N1QL primary indexes..."
COLLECTIONS.each do |coll_name|
  cluster.query(
    "CREATE PRIMARY INDEX IF NOT EXISTS ON `#{BUCKET_NAME}`.`_default`.`#{coll_name}`"
  )
  puts "  ✓ Index on #{coll_name}"
rescue => e
  puts "  ! Index error for #{coll_name}: #{e.message}"
end

scope = bucket.default_scope

# ---- Customers --------------------------------------------------------------
puts "\nInserting customers..."
customers = [
  {
    "id"             => "cust-001",
    "name"           => "Jane Smith",
    "email"          => "jane.smith@example.com",
    "phone"          => "+1-555-0101",
    "tier"           => "premium",
    "created_at"     => "2023-01-15",
    "total_orders"   => 14,
    "lifetime_value" => 1875.50
  },
  {
    "id"             => "cust-002",
    "name"           => "Bob Johnson",
    "email"          => "bob.johnson@example.com",
    "phone"          => "+1-555-0102",
    "tier"           => "standard",
    "created_at"     => "2024-02-20",
    "total_orders"   => 3,
    "lifetime_value" => 215.00
  },
  {
    "id"             => "cust-003",
    "name"           => "Maria Garcia",
    "email"          => "maria.garcia@example.com",
    "phone"          => "+1-555-0103",
    "tier"           => "premium",
    "created_at"     => "2022-08-10",
    "total_orders"   => 28,
    "lifetime_value" => 4320.00
  }
]
col = scope.collection("customers")
customers.each { |c| col.upsert(c["id"], c); puts "  ✓ #{c['name']} (#{c['email']})" }

# ---- Orders -----------------------------------------------------------------
puts "\nInserting orders..."
orders = [
  {
    "id"                 => "ord-1001",
    "customer_id"        => "cust-001",
    "status"             => "delivered",
    "items"              => [
      { "name" => "Wireless Headphones Pro", "qty" => 1, "price" => 129.99 },
      { "name" => "USB-C Cable 3-pack",      "qty" => 1, "price" => 19.99  }
    ],
    "total"              => 149.98,
    "created_at"         => "2026-05-01",
    "shipped_at"         => "2026-05-02",
    "delivered_at"       => "2026-05-05",
    "carrier"            => "UPS",
    "tracking_number"    => "1Z999AA10123456784",
    "estimated_delivery" => "2026-05-06"
  },
  {
    "id"                 => "ord-1002",
    "customer_id"        => "cust-001",
    "status"             => "shipped",
    "items"              => [
      { "name" => "Mechanical Keyboard TKL", "qty" => 1, "price" => 149.99 }
    ],
    "total"              => 149.99,
    "created_at"         => "2026-06-15",
    "shipped_at"         => "2026-06-17",
    "delivered_at"       => nil,
    "carrier"            => "USPS",
    "tracking_number"    => "9400111899223736958943",
    "estimated_delivery" => "2026-06-23"
  },
  {
    "id"                 => "ord-1003",
    "customer_id"        => "cust-002",
    "status"             => "processing",
    "items"              => [
      { "name" => "Phone Case (Clear)",   "qty" => 2, "price" => 15.99 },
      { "name" => "Screen Protector Kit", "qty" => 1, "price" => 9.99  }
    ],
    "total"              => 41.97,
    "created_at"         => "2026-06-27",
    "shipped_at"         => nil,
    "delivered_at"       => nil,
    "carrier"            => nil,
    "tracking_number"    => nil,
    "estimated_delivery" => "2026-07-03"
  }
]
col = scope.collection("orders")
orders.each { |o| col.upsert(o["id"], o); puts "  ✓ #{o['id']} (#{o['status']})" }

# ---- Support Tickets --------------------------------------------------------
puts "\nInserting support tickets..."
tickets = [
  {
    "id"          => "tkt-0001",
    "customer_id" => "cust-001",
    "subject"     => "Headphones not holding charge",
    "description" => "My Wireless Headphones Pro from ord-1001 aren't holding a charge past 20%.",
    "status"      => "resolved",
    "priority"    => "normal",
    "created_at"  => "2026-05-10T09:00:00Z",
    "updated_at"  => "2026-05-12T14:00:00Z",
    "messages"    => [
      { "role" => "customer", "content" => "Headphones won't charge past 20%.",                                "timestamp" => "2026-05-10T09:00:00Z" },
      { "role" => "agent",    "content" => "Try resetting: hold power + volume-down for 10 seconds.",           "timestamp" => "2026-05-10T10:30:00Z" },
      { "role" => "customer", "content" => "The reset worked! Charging normally now. Thank you!",               "timestamp" => "2026-05-12T14:00:00Z" }
    ]
  }
]
col = scope.collection("tickets")
tickets.each { |t| col.upsert(t["id"], t); puts "  ✓ #{t['id']} – #{t['subject']} (#{t['status']})" }

# ---- Knowledge Base ---------------------------------------------------------
puts "\nInserting knowledge base articles..."
articles = [
  {
    "id"            => "kb-001",
    "title"         => "How to Track Your Order",
    "content"       => "Track your order by visiting Order History in your account and clicking the order. " \
                       "Orders ship within 1-2 business days and typically arrive in 3-7 business days. " \
                       "A shipping confirmation email with a tracking link is sent when the order ships.",
    "tags"          => ["shipping", "tracking", "orders"],
    "helpful_votes" => 312
  },
  {
    "id"            => "kb-002",
    "title"         => "Return and Refund Policy",
    "content"       => "We offer a 30-day hassle-free return policy. Items must be in original condition. " \
                       "To initiate a return: go to Order History, select the item, and click Start Return. " \
                       "Print the prepaid label and drop at any carrier location. " \
                       "Refunds are processed within 5-7 business days after we receive the item. " \
                       "Original shipping fees are non-refundable.",
    "tags"          => ["returns", "refunds", "policy"],
    "helpful_votes" => 487
  },
  {
    "id"            => "kb-003",
    "title"         => "Order Cancellation Policy",
    "content"       => "Orders can be cancelled within 1 hour of placement if they haven't entered processing. " \
                       "Go to Order History and click Cancel Order. If processing has started, contact support immediately. " \
                       "Once shipped, refuse delivery or initiate a return upon receipt.",
    "tags"          => ["cancellation", "orders"],
    "helpful_votes" => 198
  },
  {
    "id"            => "kb-004",
    "title"         => "Damaged or Defective Items",
    "content"       => "Contact us within 7 days of delivery for damaged or defective items. " \
                       "Take clear photos of the damage before contacting support. " \
                       "We will send a free replacement or issue a full refund including return shipping. " \
                       "In most cases, you do not need to return the damaged item.",
    "tags"          => ["damaged", "defective", "warranty", "replacement"],
    "helpful_votes" => 392
  },
  {
    "id"            => "kb-005",
    "title"         => "Shipping Delays and Missing Packages",
    "content"       => "If your estimated delivery date has passed: " \
                       "(1) check carrier tracking for updates, " \
                       "(2) allow 2 additional business days, " \
                       "(3) contact us if still not received. " \
                       "For packages marked Delivered but not received, check with neighbors then contact us within 3 days. " \
                       "We will investigate and may reship or refund your order.",
    "tags"          => ["shipping", "delays", "lost", "missing", "delivery"],
    "helpful_votes" => 441
  },
  {
    "id"            => "kb-006",
    "title"         => "Account and Password Help",
    "content"       => "To reset your password, click Forgot Password on the login page and enter your email. " \
                       "A reset link arrives within 5 minutes — check spam if not received. " \
                       "To update email or account details, go to Account Settings after logging in. " \
                       "Billing address changes can be made in the Payment and Addresses section.",
    "tags"          => ["account", "password", "login", "billing"],
    "helpful_votes" => 156
  }
]
col = scope.collection("knowledge_base")
articles.each { |a| col.upsert(a["id"], a); puts "  ✓ #{a['title']}" }

# ---- Summary ----------------------------------------------------------------
puts "\n#{'=' * 55}"
puts "Seed data loaded successfully!"
puts
puts "Test customers:"
puts "  jane.smith@example.com    → cust-001 (premium,   14 orders)"
puts "  bob.johnson@example.com   → cust-002 (standard,   3 orders)"
puts "  maria.garcia@example.com  → cust-003 (premium,   28 orders)"
puts
puts "Sample orders: ord-1001 (delivered), ord-1002 (shipped), ord-1003 (processing)"
puts "Sample ticket: tkt-0001 (resolved)"
puts "KB articles:   #{articles.length} articles loaded"
puts
puts "Next: bundle exec ruby bin/chat"

cluster.disconnect
