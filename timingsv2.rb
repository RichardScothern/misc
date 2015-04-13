#!/usr/bin/env ruby

require "rubygems"
require "json"

def run_test(url, keyPrefix)
  if url == ""
    puts "Error getting blob, no URL generated"
    exit 1
  end

  stats = `curl -w "%{speed_download} %{size_download}" --max-time 900 --connect-timeout 10 --silent -D headers \"#{url}\" -o /dev/null`

  stats = stats.split(" ")
  xfer_rate = stats[0]
  bytes_xferred = stats[1].to_i

  if bytes_xferred < 10000000
    puts "Layer < 10mb (#{bytes_xferred}b)"
    exit 1
  end

  print "Layer sz=", bytes_xferred/1000000, "mb \n"
  hitMiss = `grep  "X-Cache:" headers`.split(" ")[1]

  if hitMiss == nil 
    hitMiss = "direct"
  end
    
  location = "sf"
  if ENV["location"]
    location = ENV["location"]
  end

  hostname = `hostname`.chomp
  key = "#{keyPrefix}.#{location}.#{hitMiss}"

  puts "Success: #{hitMiss}"
  dd_put(keyPrefix, xfer_rate, location, hitMiss)
  return hitMiss
end

def dd_put(metric, xfer_rate, location, hitMiss)
  now = Time.now().to_i
  
  ddkey = ENV["DDKEY"]
  if ddkey == ""
    print "No datadog key in 'DDKEY', skipping..."
  end
  host = `hostname -s`.chomp

  ddJSON = "{ \"series\" :
         [{\"metric\":\"#{metric}\",
          \"points\":[[#{now}, #{xfer_rate}]],
          \"type\":\"gauge\",
          \"host\":\"#{host}\",
          \"tags\":[\"location:#{location}\", \"cache:#{hitMiss}\"]}
        ]}"

  File.open("dd.json", 'w') {|f| f.write(ddJSON) }
  ddout=`curl -s  -X POST -H 'Content-type: application/json' -d@dd.json https://app.datadoghq.com/api/v1/series?api_key=#{ddkey}`
  puts "Sending to datadog #{ddout}"

end

repo = ARGV[0] || "tianon/speedtest"
reghost = ENV["reghost"]

# pick a random image from images.txt if arg is "random"
repo = File.readlines("images.txt").sample.chomp if repo =~ /^random/

blobs = `curl -s http://#{reghost}:5000/v2/#{repo}/manifests/latest | grep blobSum | sort | uniq`

if blobs == ""
  puts "Error finding repo #{repo}"
  exit 1
end

# get a random blob
ranblob = blobs.split("\n").sample
blob = /(sha256:\h{64})/.match(ranblob)

blobURL = "http://#{reghost}:5000/v2/#{repo}/blobs/#{blob}"

fastlyURL = `curl -v #{blobURL} 2>&1 | grep "Location:" | cut -d' ' -f3`.chomp
s3URL = `curl -v #{blobURL} 2>&1 | grep "X-Orig-Url:" | cut -d' ' -f3`.chomp

if run_test(fastlyURL, "docker.imagev2.pull.fastly") == "HIT"
  # Get a miss number for comparison for each hit
  run_test(s3URL, "docker.imagev2.pull.s3") 
end

