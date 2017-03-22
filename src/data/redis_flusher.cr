class RedisFlusher
  include Flusher

  record Degree, key : String, ttl : Int32
  
  def initialize(@redis : Redis::Client)
    @degrees = [] of Degree
    @degrees << Degree.new("%Y%m%d"    , 4.weeks.total_seconds.to_i)
    @degrees << Degree.new("%Y%m%d%H"  , 3.days.total_seconds.to_i)
    @degrees << Degree.new("%Y%m%d%H%M", 3.hours.total_seconds.to_i)

    @reporter = Periodical::Counter.new(interval: 1.minute, time_format: "%Y-%m-%d %H:%M:%S")
  end

  def flush(data : Data)
    now = Time.now
    data.each do |port, stat|
      prefix = "{zcmds}:#{port}:"
      stat.each do |cmd, cnt|
        @degrees.each do |d|
          key = prefix + now.to_s(d.key)
          @reporter.succ {
            @redis.zincrby(key, cnt, cmd)
          }
        end
      end
      @degrees.each do |d|
        key = prefix + now.to_s(d.key)
        @reporter.succ {
          @redis.expire(key, d.ttl)
        }
      end
    end
  end

  def to_s(io : IO)
    io << @redis.bootstrap.to_s
  end
end
