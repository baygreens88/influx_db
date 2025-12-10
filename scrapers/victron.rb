# fetch data from victron online portal and push to prometheus pushgateway
require 'prometheus/client'
require 'prometheus/client/push'
require 'net/http'
require 'uri'
require 'json'

#credtentials
VICTRON_URL_BASE = 'https://vrmapi.victronenergy.com/v2'
VICTRON_INSTALLATION = '448187'
VICTRON_TOKEN = 'f58dc8572107e7ccd0ae6f860403872f1efb5fa6010355ed650023c0dd3ba901'

api_url = "#{VICTRON_URL_BASE}/installations/#{VICTRON_INSTALLATION}/diagnostics"

puts "victron url: ", api_url

uri = URI(api_url)

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true # Enable SSL for HTTPS

request = Net::HTTP::Get.new(uri.request_uri)
request['x-authorization'] = "Token #{VICTRON_TOKEN}"
request['Content-Type'] = 'application/json'

response = http.request(request)

if response.is_a?(Net::HTTPSuccess)
  #pretty print json
  puts "response 200"
else
  puts "Error: #{response.code} - #{response.message}"
  exit
end

data = JSON.parse(response.body)

#extract relevant fields
#battery soc is located in [records{"id": 177}]
#total_pv_power is located in [records{"id": 259}]
#pv_south_power is located in [records{"id": 235}]
#pv_west_power is located in [records{"id": 212}]
#l1_consumption is located in [records{"id": 254}]
#l2_consumption is located in [records{"id": 246}]

#daily_yield_south is located in [records{"id": 238}]
#daily_yield_west is located in [records{"id": 215}]

#pv_to_consumption is located in [records{"id": 257}]
#battery_to_consumption is located in [records{"id": 258}]
battery_soc = nil
total_pv_power = nil
pv_south_power = nil
pv_west_power = nil
l1_consumption = nil
l2_consumption = nil
daily_yield_south = nil
daily_yield_west = nil
pv_to_consumption = nil
battery_to_consumption = nil

data['records'].each do |record|
  case record['id']
  when 177
    battery_soc = record['rawValue'].to_f
  when 259
    total_pv_power = record['rawValue'].to_f
  when 235
    pv_south_power = record['rawValue'].to_f
  when 212
    pv_west_power = record['rawValue'].to_f
  when 254
    l1_consumption = record['rawValue'].to_f
  when 246
    l2_consumption = record['rawValue'].to_f
  when 238
    daily_yield_south = record['rawValue'].to_f
  when 215
    daily_yield_west = record['rawValue'].to_f
  when 257
    pv_to_consumption = record['rawValue'].to_f
  when 258
    battery_to_consumption = record['rawValue'].to_f
  end
end

puts "battery soc: ", battery_soc
puts "total pv power: ", total_pv_power
puts "pv south power: ", pv_south_power
puts "pv west power: ", pv_west_power
puts "l1 consumption: ", l1_consumption
puts "l2 consumption: ", l2_consumption
puts "daily yield south: ", daily_yield_south
puts "daily yield west: ", daily_yield_west
puts "pv to consumption: ", pv_to_consumption
puts "battery to consumption: ", battery_to_consumption

registry = Prometheus::Client.registry
push = Prometheus::Client::Push.new(job: "ruby-victron-scraper", gateway: "http://localhost:9091")

soc_gauge = Prometheus::Client::Gauge.new(:battery_soc, docstring: 'battery state of charge in percent', labels: [:location, :device])
registry.register(soc_gauge)
soc_gauge.set(battery_soc, labels: { location: 'hemlock', device: 'victron'})

total_pv_power_gauge = Prometheus::Client::Gauge.new(:total_pv_power, docstring: 'total pv power in watts', labels: [:location, :device])
registry.register(total_pv_power_gauge)
total_pv_power_gauge.set(total_pv_power, labels: { location: 'hemlock', device: 'victron'})

string_power = Prometheus::Client::Gauge.new(:string_pv_power, docstring: 'substring power in watts', labels: [:location, :device, :string])
registry.register(string_power)
string_power.set(pv_south_power, labels: { location: 'hemlock', device: 'victron', string: 'south'})
string_power.set(pv_west_power, labels: { location: 'hemlock', device: 'victron', string: 'west'})

total_consumption = l1_consumption + l2_consumption
consumption_gauge = Prometheus::Client::Gauge.new(:total_consumption, docstring: 'total power consumption in watts', labels: [:location, :device])
registry.register(consumption_gauge)
consumption_gauge.set(total_consumption, labels: { location: 'hemlock', device: 'victron'})

daily_yield = Prometheus::Client::Gauge.new(:daily_yield, docstring: 'daily solar yield in kwh', labels: [:location, :device])
registry.register(daily_yield)
daily_yield.set(daily_yield_south + daily_yield_west, labels: { location: 'hemlock', device: 'victron'})

daily_consumption = pv_to_consumption + battery_to_consumption
daily_consumption_gauge = Prometheus::Client::Gauge.new(:daily_consumption, docstring: 'daily power consumption in kwh', labels: [:location, :device])
registry.register(daily_consumption_gauge)
daily_consumption_gauge.set(daily_consumption, labels: { location: 'hemlock', device: 'victron'})
push.add(registry)