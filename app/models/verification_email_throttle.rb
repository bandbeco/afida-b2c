# Bounds how much "verify your email address" mail can leave the domain, in two layers.
#
# Per user: a signed-in session can call EmailAddressVerificationsController#create in
# a loop, and every call sends mail. The per-user allowance makes that endpoint useless
# as an amplifier.
#
# Global: a distributed signup run presents a different user on every request, so the
# per-user allowance never trips. The global ceiling is the only bound on total volume,
# and it deliberately prefers refusing genuine signups during a burst over letting the
# sending domain be used to bomb third parties — a burned sending reputation takes weeks
# to rebuild, whereas a refused signup can be retried in an hour.
#
# Rails.cache is read at call time rather than captured at load, so tests can swap in a
# store that actually counts. ActionController::RateLimiting takes `store: cache_store`
# as a default argument evaluated when `rate_limit` is called, which binds it to the test
# environment's :null_store and is why the framework's own throttles cannot be exercised
# under test here (see test/controllers/webhooks/outrank_controller_test.rb:59).
class VerificationEmailThrottle
  PER_USER_HOURLY_LIMIT = 3
  GLOBAL_HOURLY_LIMIT = 50
  WINDOW = 1.hour
  NAMESPACE = "verification_email"

  class << self
    # Records one intended send and reports whether it is within budget.
    #
    # The global bucket is read before the user's is charged, and charged after it. Both
    # halves of that ordering matter: a send the global ceiling will refuse sends no
    # mail, so charging someone's small hourly allowance for it would keep them locked
    # out after the global window clears; and charging the user first thereafter means a
    # single looping attacker spends only its own allowance rather than draining the
    # domain's on its own rejections.
    def allow?(user)
      return false if global_spent >= global_hourly_limit

      consume("user:#{user.id}", per_user_hourly_limit) && consume("global", global_hourly_limit)
    end

    # Indirection so tests can lower the limits without reaching for constant surgery.
    def per_user_hourly_limit
      PER_USER_HOURLY_LIMIT
    end

    def global_hourly_limit
      GLOBAL_HOURLY_LIMIT
    end

    # Sends charged against the global bucket in the current window. Exposed for tests
    # and for anything that wants to report how close to the ceiling we are.
    def global_spent
      Rails.cache.read("#{NAMESPACE}:global").to_i
    end

    # Sends charged against one user's bucket in the current window.
    def user_spent(user)
      Rails.cache.read("#{NAMESPACE}:user:#{user.id}").to_i
    end

    private

    def consume(bucket, limit)
      count = Rails.cache.increment("#{NAMESPACE}:#{bucket}", 1, expires_in: WINDOW)

      # A store that cannot count (:null_store) returns nil. Allow rather than lock
      # everyone out, matching how ActionController::RateLimiting treats a nil count.
      return true if count.nil?

      count <= limit
    end
  end
end
