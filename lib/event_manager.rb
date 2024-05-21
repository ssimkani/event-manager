require 'date'
require 'time'
require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zip_code(zipcode)
  # Returns a cleaned version of a zip code.
  #
  # @param [String] (string) the zip code to be cleaned
  # @return [String] the cleaned zip code
  zipcode.to_s.rjust(5, '0')[0..4]
end

def find_reg_hours(csv)
  # Find registration hours from a CSV file.
  #
  # @param [CSV::Table] (csv) The CSV table to extract registration hours from
  # @return [Array] A sorted array of integers representing the registration hours
  arr = []
  csv.each do |row|
    reg_time = row[:regdate].split(' ')[1].gsub(':', ' ')
    hour = reg_time.split(' ')[0].to_i
    min = reg_time.split(' ')[1].to_i
    reg_hour = Time.new(1, 1, 1, hour, min).hour
    arr.push(reg_hour)
  end
  arr.sort
end

def find_reg_wdays(csv)
  # Find days of the week from a CSV file.
  #
  # @param [CSV::Table] (csv) The CSV table to extract days of the week from
  # @return [Array] A sorted array of integers representing the days of the week
  wdays_registered = []
  csv.each do |row|
    reg_date = row[:regdate].gsub('/', ' ').split(' ')
    mon = reg_date[0].to_i
    day = reg_date[1].to_i
    year = "20#{reg_date[2]}".to_i
    wdays_registered << Date.new(year, mon, day).wday
  end
  wdays_registered.sort
end

def best_times_wdays(arr)
  # Determine the count of each element in an array.
  #
  # @param [Array] (arr) The array with all registration hours or days
  # @return [Hash] A hash mapping elements to their frequency of occurrence
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
  # Maps hash keys to their corresponding day of the week. Missing days of the
  # week are filled in with a count of 0.
  #
  # @param [Hash] (hash) A hash mapping integers to their frequency of occurrence
  # @return [Hash] A hash mapping days of the week to their frequency of
  #   occurrence
  all_days = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  wdays = hash.transform_keys { |day| all_days[day] }
  all_days.each { |day| wdays[day] = 0 unless wdays.include?(day) }
  wdays
end

def writing_times_wdays_to_file(csv, csv2)
  # Writes the best registration times and days of the week to files.
  #
  # @param [CSV::Table] (csv) The CSV table with registration times
  # @param [CSV::Table] (csv2) The CSV table with registration days of the week
  # @return [void]
  times = best_times_wdays(find_reg_hours(csv))
  wdays = days_of_week(best_times_wdays(find_reg_wdays(csv2)))
  File.open('registration_hours.txt', 'w') do |file|
    file.puts '| Time of Day | Number of Registrations |'
    file.puts '|-------------|-------------------------|'
    times.each do |time, count|
      formatted_line = format('|%<time>8s     | %<count>13s           |', time: "#{time}:00", count: count)
      file.puts formatted_line
    end
  end
  File.open('registration_wdays.txt', 'w') do |file|
    file.puts '| Day of the Week | Number of Registrations |'
    file.puts '|-----------------|-------------------------|'
    wdays.each do |day, count|
      formatted_line = format('|%<day>12s     | %<count>12s            |', day: day, count: count)
      file.puts formatted_line
    end
  end
end

def clean_phone_number(phone_number)
  # Returns a cleaned version of a phone number.
  #
  # @param [String] (phone_number) the phone number to be cleaned
  # @return [String] the cleaned phone number
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
  # Returns a list of legislators for a given zipcode.
  #
  # @param [String] (zipcode) the zipcode to search
  # @return [Array] an array of legislator objects
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
  # Save a thank you letter to a file.
  #
  # @param [Integer] (id) the ID of the attendee
  # @param [String] (form_letter) the content of the letter
  # @return [void]
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

# opening instances of event_attendees.csv
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
  phone_number = clean_phone_number(row[:homephone])
  File.open('phone_numbers.txt', 'a') do |file|
    file.puts "#{name}: #{phone_number}"
  end
  zipcode = clean_zip_code(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end
contents.close

writing_times_wdays_to_file(csv, csv2)
csv.close
csv2.close
