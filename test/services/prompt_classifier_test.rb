# frozen_string_literal: true

require "test_helper"

class PromptClassifierTest < ActiveSupport::TestCase
  setup do
    @classifier = PromptClassifier.new
  end

  # Basic classification tests
  test "classifies coding prompt" do
    result = @classifier.classify("Write a Python function that sorts a list of numbers")

    assert_equal "coding", result.category
    assert result.confidence > 0
    assert result.scores.key?("coding")
  end

  test "classifies creative prompt" do
    result = @classifier.classify("Write a short story about a dragon who befriends a knight")

    assert_equal "creative", result.category
    assert result.confidence > 0
  end

  test "classifies reasoning prompt" do
    result = @classifier.classify("Calculate the probability of rolling a sum of 7 with two dice")

    assert_equal "reasoning", result.category
    assert result.confidence > 0
  end

  test "classifies research prompt" do
    result = @classifier.classify("Summarize the key differences between REST and GraphQL APIs")

    assert_equal "research", result.category
    assert result.confidence > 0
  end

  test "classifies agentic prompt" do
    result = @classifier.classify("Automate a workflow to scrape web data and store it in a database")

    assert_equal "agentic", result.category
    assert result.confidence > 0
  end

  test "classifies multimodal prompt" do
    result = @classifier.classify("Describe this image and transcribe any text in the document")

    assert_equal "multimodal", result.category
    assert result.confidence > 0
  end

  # Edge cases
  test "returns conversation for blank prompt" do
    result = @classifier.classify("")

    assert_equal "conversation", result.category
    assert_equal 0.0, result.confidence
  end

  test "returns conversation for nil prompt" do
    result = @classifier.classify(nil)

    assert_equal "conversation", result.category
    assert_equal 0.0, result.confidence
  end

  # Result structure
  test "result includes all expected fields" do
    result = @classifier.classify("Debug this Python error")

    assert_respond_to result, :category
    assert_respond_to result, :subcategory
    assert_respond_to result, :confidence
    assert_respond_to result, :scores
    assert_kind_of Hash, result.scores
  end

  test "confidence is between 0 and 1" do
    result = @classifier.classify("Write a Python function")

    assert result.confidence >= 0.0
    assert result.confidence <= 1.0
  end

  test "scores include all categories" do
    result = @classifier.classify("Write some code")

    PromptClassifier::TASK_CATEGORIES.each_key do |category|
      assert result.scores.key?(category), "Missing score for #{category}"
    end
  end

  # Subcategory detection
  test "detects debug subcategory for coding" do
    result = @classifier.classify("Debug this error in my Python code")

    assert_equal "coding", result.category
    assert_equal "debug", result.subcategory
  end

  test "detects generate subcategory for coding" do
    result = @classifier.classify("Write a function to implement binary search")

    assert_equal "coding", result.category
    assert_equal "generate", result.subcategory
  end

  test "detects refactor subcategory for coding" do
    result = @classifier.classify("Refactor this code to improve readability")

    assert_equal "coding", result.category
    assert_equal "refactor", result.subcategory
  end

  # Class method
  test "classify class method works" do
    result = PromptClassifier.classify("Write Python code")

    assert_equal "coding", result.category
    assert result.confidence > 0
  end
end
