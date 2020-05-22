require "colorize"

module Periodical
  class StatusCounter
    getter offset, count, index, ok, ko, errors

    @stopped_at : Time?

    def initialize(@total : Int32? = nil, @index : Int32 = 0, @ok : Int32 = 0, @ko : Int32 = 0, @errors : SimilarLogs = SimilarLogs.new, @color : Bool = true, @span : Time::Span = Time::Span::ZERO, @time_format : String = "%H:%M:%S")
      @started_at = Pretty.now
      @count = 0
    end

    def next
      done!
      self.class.new(total: @total, index: @index, time_format: @time_format)
    end

    def ok!(span)
      @index += 1
      @count += 1
      @ok += 1
      @span += span
    end
    
    def ko!(err)
      @index += 1
      @count += 1
      @ko += 1
      @errors << (err.message || err.class.name).to_s
    end
    
    def done!
      @stopped_at ||= Pretty.now
    end

    def done?
      !! @stopped_at
    end

    def status
      err = ko > 0 ? "# KO: #{ko}" : ""
      now = @stopped_at || Pretty.now
      hms = now.to_s(@time_format)
      if done?
        if @total
          msg = "%s done %d in %.1f sec (%s) %s" % [hms, total, sec, qps, err]
        else
          msg = "%s done %.1f sec (%s) %s" % [hms, sec, qps, err]
        end
      else
        if @total
          msg = "%s [%03.1f%%] %d/%d (%s) %s" % [hms, pct, @index, total, qps, err]
        else
          msg = "%s %d (OK:%d, KO=%d) %.1f sec (%s) %s" % [hms, count, ok, ko, sec, qps, err]
        end
      end
      colorize(msg)
    end

    def spent_hms
      h,m,s,_ = spent.to_s.split(/[:\.]/)
      h = h.to_i
      m = m.to_i
      s = s.to_i
      String.build do |io|
        io << "#{h}h" if h > 0
        io << "#{m}m" if m > 0
        io << "#{s}s" if s > 0
      end
    end
    
    def summarize
      String.build do |io|
        hms = @started_at.to_s(@time_format)
        t1  = @started_at.epoch
        t2  = stopped_at.epoch
        io << "%s (OK:%s, KO:%s) [%s +%s](%d - %d)" % [qps, ok, ko, hms, spent_hms, t1, t2]
        io << " # #{errors.first}" if errors.any?
      end
    end

    def total
      @total.not_nil!
    end
    
    def pct
      [@index * 100.0 / total, 100.0].min
    end

    def spent(now = @stopped_at || Pretty.now)
      now - @started_at
    end

    def sec
      spent.total_seconds
    end

    def qps(now = @stopped_at || Pretty.now)
      "%.1f qps" % (@count*1000.0 / spent.total_milliseconds)
    rescue
      "--- qps"
    end

    def stopped_at
      if @stopped_at.nil?
        raise "not stopped yet"
      end
      @stopped_at.not_nil!
    end

    private def colorize(msg)
      if ko > 0
        msg.colorize.yellow
      else
        msg
      end
    end
  end

  class Counter
    def initialize(@interval : Time::Span, max : Int32? = nil, @io : IO? = STDOUT, @color : Bool = true, @time_format : String = "%H:%M:%S", @error_report : Bool = false)
      raise "#{self.class} expects max > 0, bot got #{max}" if max.try(&.<= 0)

      @total   = StatusCounter.new(total: max, time_format: @time_format)
      @current = StatusCounter.new(total: max, time_format: @time_format)
    end

    def succ(raise : Bool = false)
      t1 = Pretty.now
      yield
      span = Pretty.now - t1
      @current.ok!(span)
      @total.ok!(span)
    rescue err
      @current.ko!(err)
      @total.ko!(err)
      ::raise err if raise
    ensure
      report
    end

    macro color_method(name, color)
      def {{name.id}}(msg, time : Bool = true)
        write(msg, time: time, color: {{color}})
      end
    end

    color_method(debug, nil)
    color_method(info , :green)
    color_method(warn , :yellow)
    color_method(error, :red)

    def report
      if @current.spent > @interval
        write(@current.status)
        write(@current.errors.map{|i| "  #{i}"}.join("\n")) if @error_report && @current.errors.any?
        @current = @current.next
      end
    end

    def done
      @current.done!
      @total.done!
      write(@total.status)
    end

    protected def write(msg, time : Bool = false, color : Symbol? = nil)
      msg = "#{Pretty.now.to_local.to_s(@time_format)} #{msg}" if time
      msg = msg.colorize(color) if @color && color
      @io.try(&.puts msg)
      @io.try(&.flush)
    end
  end

  class Reporter
    property! next_report_time : Time?
    property time_format

    def initialize(@interval : Time::Span, @io : IO? = STDOUT, @time_format : String = "%H:%M:%S")
      set_next_report_time
    end

    def report
      if next_report_time <= Pretty.now
        yield
        set_next_report_time
      end
    end

    private def set_next_report_time
      @next_report_time = Pretty.now + @interval
    end
  end
end
