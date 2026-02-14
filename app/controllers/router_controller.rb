# frozen_string_literal: true

class RouterController < ApplicationController
  def show
  end

  def match
    @prompt = params[:prompt].to_s.strip
    @results = AgentRouter.route(@prompt, limit: 5)
    @classification = PromptClassifier.classify(@prompt)
    render "show"
  end
end
