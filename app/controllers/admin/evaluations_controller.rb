module Admin
  class EvaluationsController < BaseController
    def index
      @eval_runs = EvalRun.includes(:agent, :eval_task)
                          .order(created_at: :desc)
                          .limit(100)
      
      @stats = {
        total_runs: EvalRun.count,
        pending: EvalRun.pending.count,
        running: EvalRun.where(status: "running").count,
        completed: EvalRun.completed.count,
        failed: EvalRun.where(status: "failed").count,
        pass_rate: calculate_pass_rate
      }
    end

    def show
      @eval_run = EvalRun.includes(:agent, :eval_task).find(params[:id])
    end

    def tasks
      @eval_tasks = EvalTask.all.order(:category, :difficulty, :name)
      @task_stats = EvalTask.left_joins(:eval_runs)
                            .group(:id)
                            .select("eval_tasks.*, COUNT(eval_runs.id) as run_count")
    end

    def task
      @eval_task = EvalTask.find(params[:id])
      @recent_runs = @eval_task.eval_runs.includes(:agent)
                               .order(created_at: :desc)
                               .limit(50)
    end

    def agent_evals
      @agent = Agent.find(params[:agent_id])
      @eval_runs = @agent.eval_runs.includes(:eval_task)
                         .order(created_at: :desc)
      @scores = @agent.agent_scores.order(evaluated_at: :desc).limit(10)
    end

    # Bulk actions
    def run_all_tier1
      agents = if params[:agent_ids].present?
                 Agent.where(id: params[:agent_ids])
               else
                 Agent.where(active: true).limit(50)
               end

      agents.find_each do |agent|
        Tier1EvaluationJob.perform_later(agent.id)
      end

      redirect_to admin_evaluations_path, 
                  notice: "Queued Tier 1 evals for #{agents.count} agents."
    end

    private

    def calculate_pass_rate
      completed = EvalRun.completed
      return 0 if completed.count.zero?
      
      passed = completed.select { |r| r.passed? }.count
      ((passed.to_f / completed.count) * 100).round(1)
    end
  end
end
