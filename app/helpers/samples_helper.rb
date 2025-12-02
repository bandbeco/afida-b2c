# Helper methods for samples pages
module SamplesHelper
  # Returns the sample limit from Cart constant
  # Use this instead of hardcoding "5" in views
  def sample_limit
    Cart::SAMPLE_LIMIT
  end
end
