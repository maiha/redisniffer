class RedisFlusher
  include Flusher

  record Degree, key : String, ttl : Int32

  def initialize(@redis : Redis::Client, @cmd_format : String = "{PORT}/{TIME}", @ip_format : String = "{PORT}/{TIME}/ip", @error_report : Bool = false)
    @stat_degrees = [] of Degree
    @stat_degrees << Degree.new("%Y%m%d"    , 4.weeks.total_seconds.to_i)
    @stat_degrees << Degree.new("%Y%m%d%H"  , 3.days.total_seconds.to_i)
    @stat_degrees << Degree.new("%Y%m%d%H%M", 3.hours.total_seconds.to_i)
    @ip_degree = Degree.new("%Y%m%d", 4.weeks.total_seconds.to_i)
    @reporter = Periodical::Counter.new(interval: 1.minute, time_format: "%Y-%m-%d %H:%M:%S", error_report: @error_report)
  end

  def flush(stats : Data, addrs : Data)
    now = Time.now

    # stats
    stats.each do |port, stat|
      stat.each do |cmd, cnt|
        @stat_degrees.each do |degree|
          key = resolve_key(now, port, degree, @cmd_format)
          @reporter.succ {
            @redis.zincrby(key, cnt, cmd)
          }
        end
      end
      @stat_degrees.each do |degree|
        key = resolve_key(now, port, degree, @cmd_format)
        @reporter.succ {
          @redis.expire(key, degree.ttl)
        }
      end
    end

    # addrs
    addrs.each do |port, hash|
      next unless hash.any?
      key = resolve_key(now, port, @ip_degree, @ip_format)
      hash.each do |ip, cnt|
        @reporter.succ {
          @redis.zincrby(key, cnt, ip)
        }
      end
      @reporter.succ {
        @redis.expire(key, @ip_degree.ttl)
      }
    end
  end

  def to_s(io : IO)
    io << "%s as '%s', '%s'" % [@redis.bootstrap, @cmd_format, @ip_format]
  end

  private def resolve_key(now, port, degree, fmt)
    # @cmd_format = "stats/{PORT}/{TIME}"
    fmt.sub("{PORT}", port.to_s).sub("{TIME}", now.to_s(degree.key))
  end
end
