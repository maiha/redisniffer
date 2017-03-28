require "../redisniffer"
require "opts"

class Main
  include Opts

  option device   : String , "-i interface", "Listen on interface", "lo"
  option output   : String , "-o uri", "Output uri (stdout, file://, redis://)", "-"
  option port     : String , "-p 6379,6380", "Capture port (overridden by -f)", "6379"
  option filter   : String?, "-f 'tcp port 6379'", "Pcap filter string. See pcap-filter(7)", nil
  option snaplen  : Int32  , "-s 1500", "Capture snapshot length", 1500
  option timeout  : Int32  , "-t 1000", "Capture timeout milliseconds", 1000
  option deny     : String , "--deny REPLCONF", "Not included in statistics", "REPLCONF,MONITOR"
  option interval : Int32  , "--out-interval 3", "Output flush interval sec", 3
  option cmd_fmt  : String , "--out-cmd-key format", "Stored redis key of cmd stats", "{PORT}/{TIME}"
  option ip_fmt   : String , "--out-ip-key format", "Stored redis key of client ip addrs", "{PORT}/{TIME}/ip"
  option need_ip  : Bool   , "--include-ip", "Store client ip address", false
  option verbose  : Bool   , "-v", "Verbose output", false
  option quiet    : Bool   , "-q", "Turn off output", false
  option version  : Bool   , "--version", "Print the version and exit", false
  option help     : Bool   , "--help"   , "Output this help and exit" , false

  property! pcap_filter : String?
  
  def run
    @pcap_filter = build_filter
    prog = Program.new(open_pcap, ports: listen_ports, deny: acl(deny), include_ip: need_ip, flusher: build_flusher, verbose: verbose)
    prog.run
  end

  private def open_pcap
    if !quiet
      STDERR.puts "listening on %s about '%s' (snaplen: %d, timeout: %d)" %
                  [device, pcap_filter, snaplen, timeout]
    end    
    pcap = Pcap::Capture.open_live(device, snaplen: snaplen, timeout_ms: timeout)
    pcap.setfilter(pcap_filter)
    return pcap
  end

  private def listen_ports : Set(Int32)
    extract_ports(pcap_filter)
  end
  
  private def build_filter : String
    if filter
      return filter.not_nil!
    else
      ports = Set(Int32).new.tap { |set| port.scan(/(\d+)/){ set << $1.to_i} }
      die "missing port" if ports.empty?
      ports.map{|i| "(tcp port #{i})"}.join(" or ")
    end
  end
  
  private def extract_ports(filter) : Set(Int32)
    # TODO: find strictly
    Set(Int32).new.tap { |set| filter.scan(/port\s+(\d+)/i){ set << $1.to_i} }
  end

  private def acl(cmd)
    cmd.split(/,/).map(&.upcase.strip).to_set
  end

  private def build_flusher : Flusher
    flusher =
      case output
      when "-"
        IOFlusher.new(io: STDOUT, clue: "Stdout")
      when %r(^file://(.*))
        path = $1.strip
        IOFlusher.new(io: File.open(path, "w+"), clue: path)
      when %r(^redis://)
        RedisFlusher.new(Redis::Client.boot(output), cmd_format: cmd_fmt, ip_format: ip_fmt)
      else
        die "unknown output: #{output}"
      end.tap(&.interval = interval.seconds)
  ensure
    STDERR.puts "output: %s" % flusher if !quiet && flusher
  end
end

Main.run
