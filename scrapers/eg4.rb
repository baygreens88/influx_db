require 'prometheus/client'
require 'prometheus/client/push'
require 'selenium-webdriver'
require 'prometheus/client'

# Initialize the Chrome driver
#driver = Selenium::WebDriver.for :remote, url: "http://localhost:63306", options: Selenium::WebDriver::Options.chrome

#run in headless mode
options = Selenium::WebDriver::Options.chrome
options.add_argument('--headless=new')
options.add_argument('--disable-gpu')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
driver = Selenium::WebDriver.for :remote, url: "http://localhost:56311", options: options

# Navigate to a website
driver.navigate.to "https://monitor.eg4electronics.com/WManage/web/login"

#driver.wait.until { driver.find_element(id: 'account') }

# fill in the login form
driver.find_element(id: 'account').send_keys('longarch')
driver.find_element(id: 'password').send_keys('Eg44011$')

puts driver.find_element(id: 'account').attribute('value')

# Submit the <button type="submit"> click
driver.find_element(tag_name: 'button', type: 'submit').click

#wait for the next page to load
sleep 5

# Print the current URL after login
puts "Current URL after login: #{driver.current_url}"

unless driver.current_url.include?("WManage/web/monitor")
#exit if login failed
    puts "Login failed"
    driver.quit
    exit
end
# Close the browser

#get text by class name
pv1Power = driver.find_element(class: 'pv1PowerText').text.strip.to_i

pv2Power = driver.find_element(class: 'pv2PowerText').text.strip.to_i

pv3Power = driver.find_element(class: 'pv3PowerText').text.strip.to_i

totalPVPower = pv1Power + pv2Power + pv3Power

puts "PV1: ", pv1Power
puts "PV2: ", pv2Power
puts "PV3: ", pv3Power
puts "PV: ", totalPVPower

soc = driver.find_element(class: 'socText').text.strip.to_i
puts "soc: ", soc

epsPower = driver.find_element(class: 'epsPowerText').text.strip.to_i
puts "inverter: ", epsPower

todayYield = driver.find_element(id: 'todayYieldingText').text.strip.to_f
todayUsage = driver.find_element(id: 'todayUsageText').text.strip.to_f

puts "today yield: ", todayYield, "today usage: ", todayUsage

driver.quit


registry = Prometheus::Client.registry
push = Prometheus::Client::Push.new(job: "ruby-eg4-scraper", gateway: "http://localhost:9091")

string_power = Prometheus::Client::Gauge.new(:string_pv_power, docstring: 'substring power in watts', labels: [:location, :device, :string])
registry.register(string_power)
string_power.set(pv1Power, labels: { location: 'hemlock', device: 'eg4-18k', string: 'east'})
string_power.set(pv2Power, labels: { location: 'hemlock', device: 'eg4-18k', string: 'south'})
string_power.set(pv3Power, labels: { location: 'hemlock', device: 'eg4-18k', string: 'north'})

total_power = Prometheus::Client::Gauge.new(:total_pv_power, docstring: 'total pv power in watts', labels: [:location, :device])
registry.register(total_power)
total_power.set(totalPVPower, labels: { location: 'hemlock', device: 'eg4-18k'})

soc_gauge = Prometheus::Client::Gauge.new(:battery_soc, docstring: 'battery state of charge in percent', labels: [:location, :device])
registry.register(soc_gauge)
soc_gauge.set(soc, labels: { location: 'hemlock', device: 'eg4-18k'})

inverter_power = Prometheus::Client::Gauge.new(:inverter_power, docstring: 'inverter output power in watts', labels: [:location, :device])
registry.register(inverter_power)
inverter_power.set(epsPower, labels: { location: 'hemlock', device: 'eg4-18k'})

daily_yield = Prometheus::Client::Gauge.new(:day_yield, docstring: 'daily solar yeild in kwh', labels: [:location, :device])
registry.register(daily_yield)
daily_yield.set(todayYield, labels: { location: 'hemlock', device: 'eg4-18k'})

daily_consumption = Prometheus::Client::Gauge.new(:day_consumption, docstring: 'daily power consumption in kwh', labels: [:location, :device])
registry.register(daily_consumption)
daily_consumption.set(todayUsage, labels: { location: 'hemlock', device: 'eg4-18k'})

push.add(registry)
