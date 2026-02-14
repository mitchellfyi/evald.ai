# frozen_string_literal: true

require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @model = create(:ai_model, :with_pricing, :with_capabilities,
                    slug: "test-model", name: "Test Model", provider: "OpenAI")
  end

  test "index returns success" do
    get models_path
    assert_response :success
  end

  test "index shows published models" do
    create(:ai_model, published: true, name: "Published Model")
    create(:ai_model, published: false, name: "Hidden Model")

    get models_path
    assert_response :success
  end

  test "index filters by provider" do
    create(:ai_model, provider: "Anthropic", name: "Claude Model")
    create(:ai_model, provider: "Google", name: "Gemini Model")

    get models_path(provider: "Anthropic")
    assert_response :success
  end

  test "show returns success for published model" do
    get model_path(@model)
    assert_response :success
  end

  test "show returns not found for unpublished model" do
    unpublished = create(:ai_model, published: false, slug: "hidden-model")

    get model_path(unpublished)
    assert_response :not_found
  end

  test "compare returns success" do
    model1 = create(:ai_model, slug: "model-a")
    model2 = create(:ai_model, slug: "model-b")

    get compare_models_path(models: "model-a,model-b")
    assert_response :success
  end

  test "compare returns success with no models" do
    get compare_models_path
    assert_response :success
  end
end
