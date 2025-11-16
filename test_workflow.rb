#!/usr/bin/env ruby
# Test script for SEO AI Engine content generation workflow

require_relative 'config/environment'

puts "=" * 80
puts "SEO AI Engine - Content Generation Workflow Test"
puts "=" * 80
puts

# Step 1: Create an opportunity
puts "Step 1: Creating opportunity..."
keyword = "sustainable paper cups #{Time.current.to_i}"
opp = SeoAiEngine::Opportunity.create!(
  keyword: keyword,
  opportunity_type: "new_content",
  score: 85,
  discovered_at: Time.current,
  status: "pending",
  search_volume: 1500,
  competition_difficulty: "medium"
)
puts "✅ Created opportunity ##{opp.id}: '#{opp.keyword}'"
puts

# Step 2: Generate content
puts "Step 2: Generating content..."
job = SeoAiEngine::ContentGenerationJob.new
job.perform(opp.id)
puts "✅ Content generation job completed"
puts

# Step 3: Verify results
opp.reload
puts "Step 3: Verifying results..."
puts "  Opportunity status: #{opp.status}"

if opp.content_brief
  brief = opp.content_brief
  puts "  ✅ Content brief created"
  puts "     - Target keyword: #{brief.target_keyword}"
  puts "     - Suggested title: #{brief.suggested_structure['title']}"
  puts "     - Word count target: #{brief.suggested_structure['word_count_target']}"

  if brief.content_draft
    draft = brief.content_draft
    puts "  ✅ Content draft created"
    puts "     - Title: #{draft.title}"
    puts "     - Status: #{draft.status}"
    puts "     - Quality score: #{draft.quality_score}"
    puts "     - Body length: #{draft.body.length} characters"
    puts "     - Generation cost: £#{draft.generation_cost_gbp}"

    # Step 4: Show review notes
    if draft.review_notes.present?
      puts "  ✅ Content reviewed"
      if draft.review_notes["strengths"]
        puts "     Strengths:"
        draft.review_notes["strengths"].each { |s| puts "       - #{s}" }
      end
      if draft.review_notes["improvements"]
        puts "     Improvements:"
        draft.review_notes["improvements"].each { |i| puts "       - #{i}" }
      end
    end

    puts
    puts "=" * 80
    puts "✅ WORKFLOW TEST PASSED!"
    puts "=" * 80
    puts
    puts "Next steps:"
    puts "  1. Start Rails server: bin/dev"
    puts "  2. Visit: http://localhost:3000/ai-seo/admin/content_drafts"
    puts "  3. Review and approve the draft"
    puts
    puts "Draft ID: #{draft.id}"
  else
    puts "  ❌ ERROR: Content draft not created"
  end
else
  puts "  ❌ ERROR: Content brief not created"
end
