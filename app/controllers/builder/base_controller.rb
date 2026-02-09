# frozen_string_literal: true
module Builder
  class BaseController < ApplicationController
    before_action :authenticate_user!
  end
end
