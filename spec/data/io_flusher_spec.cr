require "../spec_helper"

describe IOFlusher do
  describe "#flush(stats)" do
    it "write stats entries as is" do
      io = IO::Memory.new
      flusher = IOFlusher.new(io: io)

      stats = Flusher::Data.new
      addrs = Flusher::Data.new

      stats[7001] = {"PING" => 5, "AUTH" => 10}
      stats[7002] = {"CLIENT" => 1}
      flusher.flush(stats, addrs)

      io.to_s.count("\n").should eq(2)
    end
  end
end
