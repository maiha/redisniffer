class StdoutFlusher
  include Flusher

  def flush(data : Data)
    data.each do |port, stat|
      p [port, stat]
    end
  end

  def to_s(io : IO)
    io << "Stdout"
  end
end
