# frozen_string_literal: true

# Register xlsx MIME type for Excel exports
# This is normally handled by caxlsx_rails, but we register explicitly
# to ensure it's available before the controller loads
Mime::Type.register(
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  :xlsx
)
