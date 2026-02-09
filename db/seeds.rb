# frozen_string_literal: true
# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user if not exists
admin_email = Rails.application.credentials.dig(:admin, :email) || ENV.fetch("ADMIN_EMAIL", "admin@evald.ai")
admin = User.find_or_create_by!(email: admin_email) do |u|
  u.password = SecureRandom.hex(16)
end
admin.add_role(:admin) unless admin.has_role?(:admin)
puts "Admin user: #{admin.email}"

# Load all seed files from db/seeds/
Dir[Rails.root.join("db/seeds/*.rb")].sort.each do |seed_file|
  puts "Loading #{File.basename(seed_file)}..."
  load seed_file
end

# Optionally seed agents from GitHub
if ENV["SEED_AGENTS"] == "true"
  puts "Seeding agents from GitHub..."
  Rake::Task["agents:seed"].invoke
end

puts "Seeds completed successfully."
