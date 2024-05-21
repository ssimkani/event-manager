require 'date'
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

def find_reg_wdays(csv)
  wdays_registered = []
  csv.each do |row|
    reg_date = row[:regdate].gsub('/', ' ').split(' ')
    mon = reg_date[0].to_i
    day = reg_date[1].to_i
    year = "20#{reg_date[2]}".to_i
    wdays_registered << Date.new(year, mon, day).wday
  end
  wdays_registered
end

def best_times_wdays(arr)
  hash = {}
  arr.each do |element|
    if hash.key?(element)
      hash[element] += 1
    else
      hash[element] = 1
    end
  end
  hash
end

def days_of_week(hash)
  all_days = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  wdays = hash.map { |day, count| [all_days[day], count].to_h }
  all_days.each { |day| wdays[day] = 0 unless wdays.include?(day) }
  wdays
end

def writing_times_wdays_to_file(csv, csv2)
  times = best_times_wdays(find_reg_hours(csv))
  wdays = days_of_week(best_times_wdays(find_reg_wdays(csv2)))
  File.open('registration_hours.txt', 'w') do |file|
    times.each { |time, count| file.puts "#{time}:00 : #{count}" }
  end
  File.open('registration_wdays.txt', 'w') do |file|
    wdays.each { |day, count| file.puts "#{day} : #{count}" }
  end
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

csv = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

csv2 = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

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
end
contents.close

writing_times_wdays_to_file(csv, csv2)
csv.close
csv2.close
