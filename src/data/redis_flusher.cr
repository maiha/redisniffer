class RedisFlusher
  include Flusher

  record Degree, key : String, ttl : Int32

  def initialize(@redis : Redis::Client, @key_format : String = "{PORTS}/{TIME}")
    @degrees = [] of Degree
    @degrees << Degree.new("%Y%m%d"    , 4.weeks.total_seconds.to_i)
    @degrees << Degree.new("%Y%m%d%H"  , 3.days.total_seconds.to_i)
    @degrees << Degree.new("%Y%m%d%H%M", 3.hours.total_seconds.to_i)

    @reporter = Periodical::Counter.new(interval: 1.minute, time_format: "%Y-%m-%d %H:%M:%S")
  end

  def flush(data : Data)
    now = Time.now
    data.each do |port, stat|
      stat.each do |cmd, cnt|
        @degrees.each do |degree|
          key = resolve_key(now, port, degree)
          @reporter.succ {
            @redis.zincrby(key, cnt, cmd)
          }
        end
      end
      @degrees.each do |degree|
        key = resolve_key(now, port, degree)
        @reporter.succ {
          @redis.expire(key, degree.ttl)
        }
      end
    end
  end

  def to_s(io : IO)
    io << "%s as '%s'" % [@redis.bootstrap, @key_format]
  end

  private def resolve_key(now, port, degree)
    # @key_format = "{PORT}/{TIME}"
    @key_format.sub("{PORT}", port.to_s).sub("{TIME}", now.to_s(degree.key))
  end
end
