# A cache-store facade that resolves Rails.cache per call.
#
# ActionController::RateLimiting takes `store:` as a *default argument*, evaluated when
# `rate_limit` is called — that is, at class load — so an ordinarily-declared throttle is
# bound for the process's life to whatever Rails.cache was at boot. Under the test
# environment's :null_store, increment returns nil, the throttle never trips, and there is
# nothing a test can assert beyond the method existing.
#
# Passing this instead defers the lookup to request time, so the same declaration can be
# exercised by swapping Rails.cache in a test. RateLimiting only ever calls #increment.
module LiveCacheStore
  def self.increment(name, amount = 1, **options)
    Rails.cache.increment(name, amount, **options)
  end
end
