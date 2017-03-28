require "../spec_helper"

describe RedisFlusher do
  redis = Redis::Client.new

  describe "#flush(stats)" do
    it "stores into redis with three time-series" do
      redis.flushall
      flusher = RedisFlusher.new(redis)

      stats = Flusher::Data.new
      addrs = Flusher::Data.new

      stats[7001] = {"PING" => 5, "AUTH" => 10}
      stats[7002] = {"CLIENT" => 1}
      flusher.flush(stats, addrs)

      values = redis.keys("*").map{|key| redis.zrevrange(key, 0, -1, "WITHSCORES")}
      expected = [
        %(["AUTH", "10", "PING", "5"]),
        %(["AUTH", "10", "PING", "5"]),
        %(["AUTH", "10", "PING", "5"]),
        %(["CLIENT", "1"]),
        %(["CLIENT", "1"]),
        %(["CLIENT", "1"]),
      ]
      values.map(&.inspect).sort.should eq(expected)
    end

    it "respects `stat_format`" do
      redis.flushall
      flusher = RedisFlusher.new(redis, cmd_format: "x{PORT}")

      stats = Flusher::Data.new
      addrs = Flusher::Data.new

      stats[7001] = {"PING" => 5, "AUTH" => 10}
      stats[7002] = {"CLIENT" => 1}
      flusher.flush(stats, addrs)

      keys = redis.keys("*").map(&.to_s).sort
      keys.should eq(["x7001", "x7002"])
      values = keys.map{|key| redis.zrevrange(key, 0, -1, "WITHSCORES")}
      expected = [
        %(["AUTH", "30", "PING", "15"]),
        %(["CLIENT", "3"]),
      ]
      # This is a bad usage that merges same data in three times
      values.map(&.inspect).sort.should eq(expected)
    end
  end

  describe "#flush(addr)" do
    it "stores into redis as one entry for each ports" do
      redis.flushall
      flusher = RedisFlusher.new(redis)

      stats = Flusher::Data.new
      addrs = Flusher::Data.new

      addrs[7001] = {"127.0.0.1" => 5, "192.168.0.1" => 10}
      addrs[7002] = {"127.0.0.1" => 1}
      flusher.flush(stats, addrs)

      values = redis.keys("*").map{|key| redis.zrevrange(key, 0, -1, "WITHSCORES")}
      expected = [
        %(["127.0.0.1", "1"]),
        %(["192.168.0.1", "10", "127.0.0.1", "5"]),
      ]
      values.map(&.inspect).sort.should eq(expected)
    end

    it "respects `cmd_format`" do
      redis.flushall
      flusher = RedisFlusher.new(redis, ip_format: "all_clients")
      stats = Flusher::Data.new
      addrs = Flusher::Data.new

      addrs[7001] = {"127.0.0.1" => 5, "192.168.0.1" => 10}
      addrs[7002] = {"127.0.0.1" => 1}
      flusher.flush(stats, addrs)

      values = redis.keys("*").map{|key| redis.zrevrange(key, 0, -1, "WITHSCORES")}
      
      expected = [
        %(["192.168.0.1", "10", "127.0.0.1", "6"]),
      ]
      values.map(&.inspect).sort.should eq(expected)
    end
  end
end
