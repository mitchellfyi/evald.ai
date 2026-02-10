# frozen_string_literal: true

module Admin
  class TagsController < BaseController
    before_action :set_tag, only: [:show, :edit, :update, :destroy]

    def index
      @tags = Tag.popular.includes(:agents)
    end

    def show
      @agents = @tag.agents.order(score: :desc)
    end

    def new
      @tag = Tag.new
    end

    def create
      @tag = Tag.new(tag_params)
      if @tag.save
        redirect_to admin_tags_path, notice: "Tag created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @tag.update(tag_params)
        redirect_to admin_tag_path(@tag), notice: "Tag updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @tag.destroy
      redirect_to admin_tags_path, notice: "Tag deleted successfully."
    end

    private

    def set_tag
      @tag = Tag.find_by!(slug: params[:id])
    end

    def tag_params
      params.expect(tag: [:name, :slug, :color, :description])
    end
  end
end
