module Flusher
  alias Stat = Hash(String, Int32)
  alias Data = Hash(Int32, Stat)

  abstract def flush(hash : Data) : Nil
end
