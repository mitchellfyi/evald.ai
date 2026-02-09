# frozen_string_literal: true
# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user from credentials
admin_email = Rails.application.credentials.dig(:developer, :email) || ENV.fetch("ADMIN_EMAIL", "admin@evald.ai")
admin_password = Rails.application.credentials.dig(:developer, :password)

if admin_password.present?
  admin = User.find_or_initialize_by(email: admin_email)
  admin.password = admin_password
  admin.save!
  admin.add_role(:admin) unless admin.has_role?(:admin)
  puts "Admin user created/updated: #{admin.email}"
else
  puts "Warning: No developer password in credentials, skipping admin user creation"
end

# Load all seed files from db/seeds/ (skip in test to avoid polluting test DB)
unless Rails.env.test?
  Dir[Rails.root.join("db/seeds/*.rb")].sort.each do |seed_file|
    puts "Loading #{File.basename(seed_file)}..."
    load seed_file
  end
end

# Optionally seed agents from GitHub
if ENV["SEED_AGENTS"] == "true"
  puts "Seeding agents from GitHub..."
  Rake::Task["agents:seed"].invoke
end

puts "Seeds completed successfully."
