#!/usr/bin/env ruby

require 'json'

N = 1000
$data =  {"totalseen" => 0, "samples" => []}


# Get the stats for a given name
def stats()
  percentiles = [0.75, 0.90, 0.99]
  vals = $data["samples"].sort { |x,y| y <=> x }
#  print "vals: ", vals, "\n"
  print "cnt: ", vals.size, "\n"
  print "min: ", vals[vals.size-1], "\n"
  print "max: ", vals[0], "\n"

  sum = 0
  vals.each do |v|
    sum += v
  end
  avg = sum / vals.size
  puts "avg: #{avg}"

  for p in percentiles 
     print (p*100).to_i, "th: ", vals[(p*vals.size-1).to_i],"\n"
  end
end

# Add a datapoint for a given name
def add(datapoint)
  datapoint = datapoint.to_i
  if $data["totalseen"] < N
     # generate resevoir
     samples = $data["samples"]
     $data["samples"].push(datapoint)
   else
     r = rand($data["totalseen"])
     if r < $data["samples"].size
       $data["samples"][r] = datapoint       
     end
  end
  $data["totalseen"] = $data["totalseen"]+1
end

# Serialize raw data to a file
def save(statname)
  serialized = JSON.pretty_generate($data)
  File.open(statname, 'w') {|f| f.write(serialized) } 
end

# Get data for a stat
def restore(statname)
  if File.exist?(statname)
    $data = JSON.parse File.read(statname)
  end
end


if ARGF.argv.size < 2
  puts "Usage: ./stats.rb <name> <val> [--print]"
  exit 1
end
statname = ARGV[0]
statval = ARGV[1]


restore(statname)
add(statval)
save(statname)

if ARGV.size == 3 && ARGV[2] == "--print"
  stats()
end
