# frozen_string_literal: true
module Tier1
  class WorkflowEvalHarness
    def initialize(agent, eval_task)
      @agent = agent
      @eval_task = eval_task
    end

    def run
      eval_run = create_eval_run

      begin
        eval_run.update!(status: "running", started_at: Time.current)

        result = execute_workflow
        metrics = calculate_metrics(result)

        eval_run.update!(
          status: "completed",
          agent_output: result[:output],
          metrics: metrics,
          tokens_used: result[:tokens],
          duration_ms: result[:duration_ms],
          completed_at: Time.current
        )
      rescue => e
        eval_run.update!(
          status: "failed",
          metrics: { error: e.message },
          completed_at: Time.current
        )
      end

      eval_run
    end

    private

    def create_eval_run
      EvalRun.create!(
        agent: @agent,
        eval_task: @eval_task,
        status: "pending"
      )
    end

    def execute_workflow
      steps = @eval_task.expected_output&.dig("steps") || []
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      step_results = steps.map.with_index do |step, i|
        execute_step(step, i)
      end

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      {
        output: step_results.to_json,
        step_results: step_results,
        tokens: step_results.sum { |s| s[:tokens] || 0 },
        duration_ms: ((end_time - start_time) * 1000).round
      }
    end

    def execute_step(step, index)
      # Simulate step execution
      {
        step: index + 1,
        name: step["name"],
        success: rand > 0.1,  # 90% success rate simulation
        recovered: false,
        scope_violation: false,
        escalated: false,
        tokens: rand(100..500)
      }
    end

    def calculate_metrics(result)
      steps = result[:step_results] || []
      return { passed: false, completion_rate: 0 } if steps.empty?

      successful = steps.count { |s| s[:success] }
      violations = steps.count { |s| s[:scope_violation] }
      escalations = steps.count { |s| s[:escalated] }
      recoveries = steps.count { |s| s[:recovered] }
      failures = steps.count { |s| !s[:success] }

      {
        passed: successful == steps.count,
        completion_rate: successful.to_f / steps.count,
        stayed_in_scope: violations.zero?,
        scope_violations: violations,
        escalated_appropriately: escalation_appropriate?(steps),
        error_recovery_rate: failures > 0 ? recoveries.to_f / failures : 1.0
      }
    end

    def escalation_appropriate?(steps)
      # Escalation should happen on complex failures
      true  # Placeholder
    end
  end
end
