require 'bundler/setup'
require 'json'
require 'net/http'
require 'thread'

API = 'http://localhost:9292'

problem_id = ARGV.shift
solution_id = ARGV.shift

res = Net::HTTP.get_response(URI("#{API}/problems/#{problem_id}/solutions/#{solution_id}.json"))

puts res.body

if res.code.to_i != 200
  puts "Error retrieving solution"
  exit
end

data = JSON.parse(res.body)
command = data['command']

tmp_path = "/tmp/#{SecureRandom.uuid}"
file = "#{tmp_path}/code"

FileUtils.mkdir_p(tmp_path)
File.open(file, 'w') do |f|
  f.write data['code']
end

results = { 'solution' => { 'tested' => true, 'test_runs' => [] } }
command.gsub!('_file_', file)
data['tests'].each do |test|
  output = nil
  timeout = false
  timeout_thread = nil

  run_thread = Thread.new do
    output = `#{command.gsub('_input_', test['input'])}`
    timeout_thread.kill
  end

  timeout_thread = Thread.new do
    sleep 60
    run_thread.kill
    timeout = true
  end

  timeout_thread.join and run_thread.join
  data = { 'test_id' => test['id'], 'timeout' => timeout }
  if output == test['output']
    data['success'] = true
  else
    data['success'] = false
    data['output'] = output
  end

  results['solution']['test_runs'] << data
end

uri = URI("#{API}/problems/#{problem_id}/solutions/#{solution_id}.json")
req = Net::HTTP::Put.new uri, {
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}
req.body = results.to_json

res = Net::HTTP.start(uri.host, uri.port) do |http|
  http.request req
end

FileUtils.rm_rf(tmp_path)
