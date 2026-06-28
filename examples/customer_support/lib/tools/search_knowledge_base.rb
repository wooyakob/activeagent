# frozen_string_literal: true

require "ruby_llm"

# Searches KB articles and FAQs to help resolve customer issues.
class SearchKnowledgeBase < RubyLLM::Tool
  description "Search the knowledge base for help articles and FAQs relevant to the customer's issue. " \
              "Use this before creating a support ticket."

  param :query,
    type: "string",
    desc: "Topic or issue to search for (e.g. 'return policy', 'track order', 'damaged item')"

  def initialize(store)
    @store = store
  end

  def execute(query:)
    articles = @store.search_knowledge_base(query)

    return { found: false, message: "No articles found for: #{query}" } if articles.empty?

    {
      found:    true,
      articles: articles.map do |a|
        {
          id:      a["id"],
          title:   a["title"],
          content: a["content"],
          tags:    a["tags"]
        }
      end
    }
  end
end
