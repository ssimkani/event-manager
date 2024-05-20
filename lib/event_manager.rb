require 'time'
require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zip_code(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def find_reg_hours(csv)
  arr = []
  csv.each do |row|
    reg_time = row[:regdate].split(' ')[1].gsub(':', ' ')
    hour = reg_time.split(' ')[0].to_i
    min = reg_time.split(' ')[1].to_i
    reg_hour = Time.new(1, 1, 1, hour, min).hour
    arr.push(reg_hour)
  end
  arr
end

def clean_phone_number(phone_number)
  phone_number.delete!('^0-9')
  if phone_number.length < 10 || phone_number.length > 11 || (phone_number.length == 11 && phone_number[0] != '1')
    'Bad Number'
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number[1..]
  else
    phone_number
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zip_code(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)

  puts "#{name} #{phone_number} #{legislators}"
end
