module LeadMonitor
  # Only shares Rails' database connection, not storefront model behavior.
  class Record < ActiveRecord::Base
    self.abstract_class = true
  end
end
