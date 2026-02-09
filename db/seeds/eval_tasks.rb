# Coding eval tasks
EvalTask.find_or_create_by!(name: "Fix Syntax Error") do |t|
  t.category = "coding"
  t.difficulty = "easy"
  t.description = "Fix the syntax error in the given code"
  t.prompt = "Fix this code: def hello(\n  puts 'hello'\nend"
  t.expected_output = { "fixed_code" => "def hello\n  puts 'hello'\nend" }
  t.timeout_seconds = 60
end

EvalTask.find_or_create_by!(name: "Implement Function") do |t|
  t.category = "coding"
  t.difficulty = "medium"
  t.description = "Implement a function based on the spec"
  t.prompt = "Write a Ruby function that reverses a string without using .reverse"
  t.expected_output = { "has_function" => true, "passes_tests" => true }
  t.timeout_seconds = 120
end

# Research eval tasks
EvalTask.find_or_create_by!(name: "Fact Retrieval") do |t|
  t.category = "research"
  t.difficulty = "easy"
  t.description = "Retrieve specific facts from a knowledge base"
  t.prompt = "What year was Ruby first released?"
  t.expected_output = { "facts" => [ "1995" ], "keywords" => [ "ruby", "matsumoto" ] }
  t.timeout_seconds = 60
end
