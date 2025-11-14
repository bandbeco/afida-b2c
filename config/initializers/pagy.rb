# Pagy initializer
# See https://ddnexus.github.io/pagy/docs/api/pagy/

require "pagy"
require "pagy/toolbox/helpers/series_nav"

# Set default items per page
Pagy.options[:limit] = 50

# Handle page overflow gracefully (redirect to last page instead of raising error)
Pagy.options[:overflow] = :last_page

# Include Pagy method in controllers and views
# Pagy 43.x provides pagy() method through Pagy::Method module
ActiveSupport.on_load(:action_controller_base) do
  include Pagy::Method   # provides pagy() method for controllers
end

ActiveSupport.on_load(:action_view) do
  include Pagy::Method   # provides pagy() method and pagination helpers for views
end
