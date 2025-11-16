# Test script for performance tracking and budget management

puts '=== Creating Sample Data ==='

# Create opportunity
opp = SeoAiEngine::Opportunity.create!(
  keyword: 'sustainable coffee cups',
  search_volume: 2000,
  competition_difficulty: 'medium',
  score: 75,
  opportunity_type: 'new_content',
  status: 'completed',
  discovered_at: 3.weeks.ago
)

# Create content brief
brief = SeoAiEngine::ContentBrief.create!(
  opportunity: opp,
  target_keyword: opp.keyword,
  suggested_structure: {
    'title' => 'The Complete Guide to Sustainable Coffee Cups',
    'h2_sections' => [ 'What are Sustainable Coffee Cups?', 'Benefits', 'How to Choose' ]
  }
)

# Create content draft
draft = SeoAiEngine::ContentDraft.create!(
  content_brief: brief,
  title: 'The Complete Guide to Sustainable Coffee Cups',
  body: 'Sample content here...',
  meta_title: 'Sustainable Coffee Cups Guide',
  meta_description: 'Learn about sustainable coffee cups.',
  content_type: 'blog',
  status: 'approved'
)

# Create content item (published)
item = SeoAiEngine::ContentItem.create!(
  content_draft: draft,
  title: draft.title,
  body: draft.body,
  slug: 'sustainable-coffee-cups-guide',
  meta_title: draft.meta_title,
  meta_description: draft.meta_description,
  status: 'published',
  published_at: 2.weeks.ago
)

puts "Created ContentItem ##{item.id}: #{item.title}"

# Run PerformanceTrackingJob
puts ''
puts '=== Running PerformanceTrackingJob ==='
SeoAiEngine::PerformanceTrackingJob.perform_now

# Check results
snapshots = SeoAiEngine::PerformanceSnapshot.all
puts "Created #{snapshots.count} performance snapshots"
snapshots.each do |snap|
  if snap.content_item
    puts "  - #{snap.content_item.title}: #{snap.impressions} imp, #{snap.clicks} clicks"
  else
    puts "  - Site-wide: #{snap.impressions} imp, #{snap.clicks} clicks"
  end
end

puts ''
puts 'Performance tracking test completed!'
