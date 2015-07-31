Fabricator(:publication) do
  title { Faker::Lorem.words(5).join(' ') }
  body { Faker::Lorem.paragraph(2) }
  year Time.now.year
  visible true
end
