class Admin::ApplicationController < ApplicationController
  include AdminAuthorization
  layout "admin"
end
