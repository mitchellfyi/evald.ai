# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user if not exists
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@evaled.ai")
admin = User.find_or_create_by!(email: admin_email) do |u|
  u.password = SecureRandom.hex(16)
end
admin.add_role(:admin) unless admin.has_role?(:admin)
puts "Admin user: #{admin.email}"
