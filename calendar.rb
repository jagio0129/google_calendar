require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'time'
require 'date'
require 'yaml'
require 'fileutils'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'Google Calendar API Ruby Quickstart'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                             "calendar-ruby-quickstart.yaml")
YAML_PATH = 'setting.yml'
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(
    client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(
      base_url: OOB_URI)
    puts "Open the following URL in the browser and enter the " +
         "resulting code after authorization"
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI)
  end
  credentials
end

def mk_markdown(worker)
  file_name = "#{DateTime.now().strftime("%d").to_s}-#{ARGV[0]}-00-saga.md"
  
  worker.each do |name|
    File.open(file_name,"a") do |file|
      file.puts("- #{name.summary}")
    end
  end
end

raise "オプションに\"時間(ex 13:00)\"を指定してください" if ARGV[0].nil?

yaml = YAML.load_file(YAML_PATH)
# Initialize the API
service = Google::Apis::CalendarV3::CalendarService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# Fetch the next 10 events for the user
calendar_id = yaml["google"]["calender_id"]
today = DateTime.now().iso8601
response = service.list_events(calendar_id,
                               max_results: 20,
                               single_events: true,
                               order_by: 'startTime',
                               time_min: today,
                               )

puts "Upcoming events:"
puts "No upcoming events found" if response.items.empty?

worker = []
response.items.each do |event|
  start = event.start.date || event.start.date_time
  if 4 == start.day
    if start.hour.to_s == ARGV[0]
      puts "- #{event.summary} #{start}"
      worker.push(event)
    end
  end
end
mk_markdown(worker)