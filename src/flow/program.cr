class Program
  def initialize(@pcap : Pcap::Capture, @ports : Set(Int32), @deny : Set(String), @flusher : Flusher, @verbose : Bool = false)
  end

  def run
    hash = Flusher::Data.new # port => {cmd => count}
    last_flushed_at = Time.now
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
        hash[port] ||= Hash(String, Int32).new { 0 }
        hash[port][cmd] += 1
      end

      if Time.now > last_flushed_at + flusher.interval
        flusher.flush(hash)
        hash.clear
        last_flushed_at = Time.now
      end
    end
  end
end
