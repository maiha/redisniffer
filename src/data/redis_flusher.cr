class RedisFlusher
  include Flusher

  record Degree, time_fmt : String, ttl : Int32
  delegate fixed_slot?, resolve_key, to: self.class

  @pipeline_mode : Bool

  def initialize(@client : Redis::Client, @cmd_fmt : String = "{PORT}/{TIME}", @ip_fmt : String = "{PORT}/{TIME}/ip", @error_report : Bool = false)
    @stat_degrees = [] of Degree
    @stat_degrees << Degree.new("%Y%m%d"    , 4.weeks.total_seconds.to_i)
    @stat_degrees << Degree.new("%Y%m%d%H"  , 3.days.total_seconds.to_i)
    @stat_degrees << Degree.new("%Y%m%d%H%M", 3.hours.total_seconds.to_i)
    @ip_degree = Degree.new("%Y%m%d", 4.weeks.total_seconds.to_i)
    @reporter = Periodical::Counter.new(interval: 1.minute, time_format: "%Y-%m-%d %H:%M:%S", error_report: @error_report)

    @pipeline_mode = !!(@client.standard? || fixed_slot?(@cmd_fmt))
  end

  def flush(stats : Data, addrs : Data)
    now = Time.now
    if @pipeline_mode
      # We can use pipeline for the case of server is in single node or all keys are in same node.
      @client.pipelined(resolve_key(@cmd_fmt), reconnect: true) do |redis|
        @reporter.succ(raise: true) {
          flush_internal(redis, stats, addrs, now)
        }
      end
    else
      # Sending request one by one. `@client` guarantees `retry`.
      flush_internal(@client, stats, addrs, now)
    end
  rescue err
    # Report immediately if unexpected errors happened.
    # Then, close redis in order to create a new connection in next request.
    STDERR.puts "#{Time.now}: unexpected error(#{err.class}) in `#{self.class}#flush'"
    STDERR.puts err.inspect_with_backtrace
  end

  def flush_internal(redis, stats : Data, addrs : Data, now : Time)
    # stats
    stats.each do |port, stat|
      @stat_degrees.each do |degree|
        key = resolve_key(@cmd_fmt, port, now.to_s(degree.time_fmt))
        stat.each do |cmd, cnt|
          redis.zincrby(key, cnt, cmd)
        end
        redis.expire(key, degree.ttl)
      end
    end

    # addrs
    addrs.each do |port, hash|
      next unless hash.any?
      key = resolve_key(@ip_fmt, port, now.to_s(@ip_degree.time_fmt))
      hash.each do |ip, cnt|
        redis.zincrby(key, cnt, ip)
      end
      redis.expire(key, @ip_degree.ttl)
    end
  end

  def to_s(io : IO)
    pipeline = @pipeline_mode ? "(pipelined)" : ""
    io << "%s to '%s', '%s' %s" % [@client.bootstrap, @cmd_fmt, @ip_fmt, pipeline]
  end
end

class RedisFlusher
  def self.resolve_key(fmt, port = 0, time = "")
    # fmt = "stats/{PORT}/{TIME}"
    fmt.sub("{PORT}", port.to_s).sub("{TIME}", time.to_s)
  end

  def self.fixed_slot?(fmt) : Bool
    return true if !fmt.includes?("{PORT}") && !fmt.includes?("{TIME}")
    return !!(resolve_key(fmt, "", "") =~ /\{.*\}/)
  end
end
