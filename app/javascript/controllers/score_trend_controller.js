import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    agentSlug: String
  }

  connect() {
    this.loadChart()
  }

  async loadChart() {
    try {
      const response = await fetch(this.urlValue)
      if (!response.ok) throw new Error("Failed to load score history")
      
      const { data, trend, current_score } = await response.json()
      
      if (data.length < 2) {
        this.showNoDataMessage()
        return
      }

      this.renderChart(data)
      this.updateTrendIndicator(trend)
    } catch (error) {
      console.error("Score trend error:", error)
      this.showNoDataMessage()
    }
  }

  renderChart(data) {
    const canvas = this.element.querySelector("canvas")
    if (!canvas) return

    const ctx = canvas.getContext("2d")
    const labels = data.map(d => this.formatDate(d.date))
    const scores = data.map(d => d.score)

    // Determine gradient colors based on trend
    const gradient = ctx.createLinearGradient(0, 0, 0, 150)
    gradient.addColorStop(0, "rgba(99, 102, 241, 0.3)")
    gradient.addColorStop(1, "rgba(99, 102, 241, 0.05)")

    new Chart(ctx, {
      type: "line",
      data: {
        labels: labels,
        datasets: [{
          label: "Evald Score",
          data: scores,
          borderColor: "#6366f1",
          backgroundColor: gradient,
          fill: true,
          tension: 0.3,
          borderWidth: 2,
          pointRadius: 3,
          pointBackgroundColor: "#6366f1",
          pointHoverRadius: 5
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: "#1f2937",
            titleColor: "#fff",
            bodyColor: "#fff",
            padding: 10,
            displayColors: false,
            callbacks: {
              label: (context) => `Score: ${context.parsed.y.toFixed(1)}`
            }
          }
        },
        scales: {
          x: {
            display: true,
            grid: {
              display: false
            },
            ticks: {
              maxTicksLimit: 6,
              font: {
                size: 11
              },
              color: "#9ca3af"
            }
          },
          y: {
            display: true,
            min: 0,
            max: 100,
            grid: {
              color: "#f3f4f6"
            },
            ticks: {
              stepSize: 25,
              font: {
                size: 11
              },
              color: "#9ca3af"
            }
          }
        },
        interaction: {
          intersect: false,
          mode: "index"
        }
      }
    })
  }

  updateTrendIndicator(trend) {
    const indicator = this.element.querySelector("[data-trend-indicator]")
    if (!indicator) return

    const config = {
      improving: { icon: "↑", class: "text-green-600", label: "Improving" },
      declining: { icon: "↓", class: "text-red-600", label: "Declining" },
      stable: { icon: "→", class: "text-gray-600", label: "Stable" }
    }

    const { icon, class: colorClass, label } = config[trend] || config.stable
    indicator.innerHTML = `<span class="${colorClass} font-medium">${icon} ${label}</span>`
    indicator.classList.remove("hidden")
  }

  formatDate(dateStr) {
    const date = new Date(dateStr)
    return date.toLocaleDateString("en-US", { month: "short", day: "numeric" })
  }

  showNoDataMessage() {
    const canvas = this.element.querySelector("canvas")
    if (canvas) {
      canvas.style.display = "none"
    }
    
    const message = this.element.querySelector("[data-no-data]")
    if (message) {
      message.classList.remove("hidden")
    }
  }
}
