# Acme Store Customer Support Agent

An agentic customer support application built with the [ruby_llm](https://github.com/crmne/ruby_llm) gem and the [Couchbase Ruby SDK](https://github.com/couchbase/couchbase-ruby-client). The agent uses Claude to hold natural conversations with customers while querying live data from Couchbase through tool calls.

## Architecture

```
bin/chat
  └── SupportAgent          ← orchestrates conversation + tools
        ├── RubyLLM::Chat   ← manages message history, tool dispatch, Claude API
        ├── CouchbaseStore  ← N1QL queries + KV operations
        └── Tools (6):
              LookupCustomer        → customers collection (KV + N1QL)
              GetOrderStatus        → orders collection (KV + N1QL)
              SearchKnowledgeBase   → knowledge_base collection (N1QL LIKE)
              CreateSupportTicket   → tickets collection (KV upsert)
              UpdateTicketStatus    → tickets collection (KV get + upsert)
              ListCustomerTickets   → tickets collection (N1QL)
```

**Couchbase data model** — one bucket (`customer_support`), four named collections in `_default` scope:

| Collection       | Purpose                              | Access pattern          |
|-----------------|--------------------------------------|-------------------------|
| `customers`      | Customer profiles                    | KV by ID, N1QL by email |
| `orders`         | Order history and shipping status    | KV by ID, N1QL by customer |
| `tickets`        | Support ticket threads               | KV + N1QL               |
| `knowledge_base` | FAQ and help articles                | N1QL full-text LIKE     |

## Prerequisites

- **Ruby** 3.1+
- **Couchbase Server** 7.x ([download](https://www.couchbase.com/downloads/) or use Capella)
- **Anthropic API key** — [get one here](https://console.anthropic.com/)
- A Couchbase bucket named `customer_support`

## Setup

### 1. Install dependencies

```bash
cd examples/customer_support
bundle install
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env and fill in your ANTHROPIC_API_KEY and Couchbase credentials
```

### 3. Create the Couchbase bucket

In the Couchbase Web Console (`http://localhost:8091`), create a bucket named `customer_support` (128 MB RAM is sufficient for the demo).

Or via CLI:
```bash
couchbase-cli bucket-create \
  -c localhost -u Administrator -p password \
  --bucket customer_support \
  --bucket-type couchbase \
  --bucket-ramsize 128
```

### 4. Seed sample data

This creates the four collections, primary indexes for N1QL, and loads sample data:

```bash
bundle exec ruby seed_data.rb
```

Expected output:
```
Creating collections in 'customer_support'...
  ✓ Created: customers
  ✓ Created: orders
  ✓ Created: tickets
  ✓ Created: knowledge_base
Creating N1QL primary indexes...
  ✓ Index on customers
  ...
Seed data loaded successfully!
```

### 5. Start the chat agent

```bash
bundle exec ruby bin/chat
```

## Example Conversation

```
You: Hi, I haven't received my order yet — it was supposed to arrive 3 days ago.

Agent: I'm sorry to hear that! I'd be happy to look into this for you.
       Could you share the email address on your account?

You: Sure, it's jane.smith@example.com

Agent: Thanks, Jane! I found your account. Let me check your recent orders...
       I can see order ord-1002 (Mechanical Keyboard TKL) was shipped on June 17th
       via USPS with tracking number 9400111899223736958943.
       The estimated delivery was June 23rd. Based on our policy, I'd recommend
       waiting one more business day and tracking via USPS.
       Would you like me to open a support ticket so our team can follow up if
       it still doesn't arrive?

You: Yes please, I'm getting worried.

Agent: I've created ticket tkt-a3f2 for you regarding the delayed delivery.
       Our team will follow up within 24 hours. Is there anything else I can
       help you with today?
```

## Customisation

### Change the Claude model

Set `CLAUDE_MODEL` in your `.env` file:

```
CLAUDE_MODEL=claude-sonnet-4-6
```

Any model supported by `ruby_llm` and the Anthropic API will work.

### Add a new tool

1. Create `lib/tools/my_tool.rb` extending `RubyLLM::Tool`
2. Define `description`, `param` declarations, and `def execute(**kwargs)`
3. Add `MyTool.new(@store)` to the `.with_tools(...)` call in `lib/support_agent.rb`

### Swap out Couchbase

`CouchbaseStore` is the only file that talks to the database. Replace its implementation with any datastore — the tools and agent code are completely unaware of the storage layer.

### Production considerations

- Replace primary indexes with targeted composite indexes on frequently queried fields
- Add Couchbase FTS (Full-Text Search) for smarter knowledge-base queries
- Persist conversation history to Couchbase (store `@chat.messages` as a ticket thread)
- Deploy the agent behind a Rails controller or Sinatra route for web-based chat
- Use [ActiveAgent](https://github.com/activeagents/activeagent) for a full Rails integration
