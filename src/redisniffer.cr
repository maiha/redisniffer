require "colorize"

require "app"
require "try"
require "pcap"
require "redis-cluster"

require "./lib/**"
require "./data/**"
require "./flow/**"

def truncate(buf, size)
  buf = buf.to_s
  buf = buf[0, size] + "..." if buf.size > size
  buf
end

macro debug(buf)
  puts "DEBUG: [%s] %s" % [self.class, truncate({{buf}}, 60)]
end
