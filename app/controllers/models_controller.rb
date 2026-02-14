# frozen_string_literal: true

class ModelsController < ApplicationController
  PER_PAGE = 25

  def index
    models = AiModel.published.active.order(:provider, :name)

    if params[:provider].present?
      models = models.by_provider(params[:provider])
    end

    if params[:family].present?
      models = models.by_family(params[:family])
    end

    @providers = AiModel.published.active.distinct.pluck(:provider).sort
    @total_count = models.count
    @page = (params[:page] || 1).to_i
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
    @page = [[@page, 1].max, @total_pages].min if @total_pages > 0

    @models = models.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show
    @model = AiModel.published.find_by!(slug: params[:id])
  end

  def compare
    slugs = params[:models].to_s.split(",").map(&:strip).first(4)
    @models = AiModel.published.where(slug: slugs)
  end
end
