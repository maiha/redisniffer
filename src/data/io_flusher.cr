class IOFlusher
  include Flusher

  def initialize(@io : IO, @clue : String = "IO")
  end

  def flush(stats : Data, addrs : Data)
    (stats.keys | addrs.keys).sort.each do |port|
      @io.puts [port, stats[port]?, addrs[port]?].inspect
    end
  end

  def to_s(io : IO)
    io << @clue
  end
end
