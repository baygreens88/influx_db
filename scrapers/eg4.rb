require 'prometheus/client'
require 'prometheus/client/push'
require 'selenium-webdriver'
require 'open3'

def executable_major_version(path)
  return nil if path.nil? || path.strip.empty? || !File.executable?(path)

  output, status = Open3.capture2e(path, '--version')
  return nil unless status.success?

  output[/(\d+)\./, 1]&.to_i
rescue StandardError
  nil
end

def existing_executable_paths(paths)
  paths.select { |path| path && File.executable?(path) }
end

def resolve_local_browser_binaries(base_dir)
  chrome_candidates = [
    ENV['EG4_CHROME_BINARY'],
    *Dir.glob(File.join(base_dir, 'chrome', 'mac_arm-*', 'chrome-mac-arm64', 'Google Chrome for Testing.app', 'Contents', 'MacOS', 'Google Chrome for Testing')).sort.reverse,
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
  ]

  driver_candidates = [
    ENV['EG4_CHROMEDRIVER_BINARY'],
    *Dir.glob(File.join(base_dir, 'chromedriver', 'mac_arm-*', 'chromedriver-mac-arm64', 'chromedriver')).sort.reverse
  ]

  chrome_candidates = existing_executable_paths(chrome_candidates)
  driver_candidates = existing_executable_paths(driver_candidates)
  driver_versions = driver_candidates.to_h { |driver| [driver, executable_major_version(driver)] }

  chrome_candidates.each do |chrome|
    chrome_version = executable_major_version(chrome)
    next if chrome_version.nil?

    matched_driver = driver_candidates.find { |driver| driver_versions[driver] == chrome_version }
    return [chrome, matched_driver] if matched_driver
  end

  [chrome_candidates.first, driver_candidates.first]
end

base_dir = __dir__
chrome_binary, chromedriver_binary = resolve_local_browser_binaries(base_dir)
if chrome_binary.nil? || chromedriver_binary.nil?
  warn 'Could not find usable Chrome and chromedriver binaries. Set EG4_CHROME_BINARY and EG4_CHROMEDRIVER_BINARY.'
  exit 1
end

remote_url = ENV['EG4_SELENIUM_REMOTE_URL']

# run in headless mode
options = Selenium::WebDriver::Options.chrome
options.binary = chrome_binary
options.add_argument('--headless=new')
options.add_argument('--disable-gpu')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')

driver =
  if remote_url && !remote_url.strip.empty?
    Selenium::WebDriver.for :remote, url: remote_url, options: options
  else
    service = Selenium::WebDriver::Service.chrome(path: chromedriver_binary)
    Selenium::WebDriver.for :chrome, options: options, service: service
  end

# Navigate to a website
driver.navigate.to "https://monitor.eg4electronics.com/WManage/web/login"

#driver.wait.until { driver.find_element(id: 'account') }

# fill in the login form
creds_path = ENV.fetch('EG4_CREDS_FILE', File.expand_path('eg4.creds', __dir__))
creds = {}
if File.exist?(creds_path)
  File.read(creds_path).each_line do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    key, value = line.split('=', 2)
    next if key.nil? || value.nil?
    creds[key.strip] = value.strip
  end
end

eg4_username = creds['EG4_USERNAME']
eg4_password = creds['EG4_PASSWORD']
if eg4_username.nil? || eg4_password.nil? || eg4_username.strip.empty? || eg4_password.strip.empty?
  puts "EG4_USERNAME and EG4_PASSWORD are required in #{creds_path}"
  driver.quit
  exit
end
driver.find_element(id: 'account').send_keys(eg4_username)
driver.find_element(id: 'password').send_keys(eg4_password)

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

l1_consumption = Float(driver.find_element(class: 'epsL1nText').text.strip) rescue Float::NAN
l2_consumption = Float(driver.find_element(class: 'epsL2nText').text.strip) rescue Float::NAN

puts "PV1: ", pv1Power
puts "PV2: ", pv2Power
puts "PV3: ", pv3Power
puts "PV: ", totalPVPower

puts "L1 consumption: ", l1_consumption
puts "L2 consumption: ", l2_consumption

soc = Float(driver.find_element(class: 'socText').text.strip) rescue Float::NAN
puts "soc: ", soc

zero_or_nan = ->(value) { value.respond_to?(:nan?) ? value.nan? || value.zero? : value.to_f.nan? || value.to_f.zero? }

if zero_or_nan.call(l1_consumption) && zero_or_nan.call(l2_consumption) && zero_or_nan.call(soc)
  puts 'l1_consumption, l2_consumption, and soc are all zero or NaN; skipping pushgateway update'
  driver.quit
  exit 0
end

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

l1_consumption_gauge = Prometheus::Client::Gauge.new(:l1_consumption, docstring: 'l1 power consumption in watts', labels: [:location, :device])
registry.register(l1_consumption_gauge)
l1_consumption_gauge.set(l1_consumption, labels: { location: 'hemlock', device: 'eg4-18k'})

l2_consumption_gauge = Prometheus::Client::Gauge.new(:l2_consumption, docstring: 'l2 power consumption in watts', labels: [:location, :device])
registry.register(l2_consumption_gauge)
l2_consumption_gauge.set(l2_consumption, labels: { location: 'hemlock', device: 'eg4-18k'})

push.add(registry)
