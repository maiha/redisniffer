class RedisFlusher
  include Flusher

  property key_builder : Proc((String, Int32), String)
  
  def initialize(@redis : Redis::Client, @ttl : Time::Span = 3.days)
    @time_format = "%Y%m%d%H%M"
    @key_builder = ->(prefix: String, port: Int32){ "#{prefix}:{#{port}}" }
  end
    
  def flush(data : Data)
    prefix = Time.now.to_s(@time_format)
    data.each do |port, stat|
      key = key_builder.call(prefix, port)
      @redis.set(key, stat.inspect)
      @redis.expire(key, @ttl.seconds)
    end
  end

  def to_s(io : IO)
    io << @redis.bootstrap.to_s
  end
end
