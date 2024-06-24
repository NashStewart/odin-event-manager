require 'csv'
require 'time'
require 'erb'
require 'google/apis/civicinfo_v2'

def sorted_by_value(hash)
  hash.sort_by { |_, hour_count| -hour_count }.to_h
end

def registration_day(registration_date)
  Date.strptime(registration_date, '%m/%d/%y %k:%M').wday
end

def registration_hour(registration_date)
  Time.strptime(registration_date, '%m/%d/%y %k:%M').hour
end

def clean_phone_number(phone_number)
  just_digits = phone_number.to_s.gsub /\D/, ''
  just_digits.slice!(0) if just_digits.length == 11 && just_digits[0] == '1'
  return just_digits.insert(3, '-').insert(7, '-') if just_digits.length == 10
  
  '000-000-0000'
end

def clean_zip_code(zip_code)
  zip_code.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zip_code(zip_code)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  
  begin
    legislators = civic_info.representative_info_by_address(
      address: zip_code,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody'],
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir 'output' unless Dir.exist? 'output'
  file_name = "output/thanks_#{id}.html"
  File.open(file_name, 'w') { |file| file.puts form_letter }
end


puts "EventsManager initialized.\n\n"

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read 'form_letter.erb'
erb_template = ERB.new template_letter
registration_hours = Hash.new 0
registration_days = Hash.new 0

contents.each do |row|
  id = row[0]
  first_name = row[:first_name]
  zip_code = clean_zip_code row[:zipcode]
  legislators = legislators_by_zip_code zip_code
  form_letter = erb_template.result binding
  save_thank_you_letter id, form_letter
 
  phone_number = clean_phone_number row[:homephone]
  registration_hour = registration_hour row[:regdate]
  registration_hours["#{registration_hour}:00"] += 1
  registration_day = registration_day row[:regdate]
  registration_days[registration_day] += 1
end

puts "Peak Registration Hours: #{sorted_by_value registration_hours}"
puts "Peak Registration Days: #{sorted_by_value registration_days}"
