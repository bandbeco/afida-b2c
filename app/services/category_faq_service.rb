# frozen_string_literal: true

class CategoryFaqService
  class << self
    def for_category(slug)
      all_faqs[slug] || []
    end

    def all_slugs
      all_faqs.keys
    end

    def reload!
      @all_faqs = nil
    end

    private

    def all_faqs
      @all_faqs ||= YAML.load_file(Rails.root.join("config/category_faqs.yml"))
    end
  end
end
