class Program
  def initialize(@pcap : Pcap::Capture, @ports : Set(Int32), @deny : Set(String), @flusher : Flusher, @include_ip : Bool = false, @verbose : Bool = false)
  end

  def run
    stats = Flusher::Data.new # port => {cmd => count}
    addrs = Flusher::Data.new # port => {ip_addr => count}
    last_flushed_at = Pretty.now
    flusher = @flusher

    @pcap.loop do |pkt|
      next unless pkt.tcp_data?
      debug pkt.tcp_data.to_s.inspect if @verbose
      port = pkt.tcp_header.dst.to_i32

      next unless @ports.includes?(port)

      case pkt.tcp_data.to_s
      when /\A\*\d+\r\n\$\d+\r\n(.*?)\r/
        cmd = $1.upcase
        next if @deny.includes?(cmd)
        stats[port] ||= Hash(String, Int32).new { 0 }
        stats[port][cmd] += 1

        if @include_ip
          addrs[port] ||= Hash(String, Int32).new { 0 }
          addrs[port][pkt.ip_header.src_str] += 1
        end
      end

      if Pretty.now > last_flushed_at + flusher.interval
        flusher.flush(stats, addrs)
        stats.clear
        addrs.clear
        last_flushed_at = Pretty.now
      end
    end
  end
end
