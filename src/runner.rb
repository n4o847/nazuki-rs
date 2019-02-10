module Nazuki
  class Runner
    def initialize(code)
      @mem = [0]
      @ptr = 0
      @pc = -1
      @code = code.chars.map do |char|
        case char
        when "+" then :inc
        when "-" then :dec
        when ">" then :right
        when "<" then :left
        when "[" then :open
        when "]" then :close
        when "," then :get
        when "." then :put
        end
      end.compact
      stack = []
      @corr = {}
      @code.each_with_index do |op, idx|
        case op
        when :open
          stack.push(idx)
        when :close
          if stack.empty?
            raise "unmatched ]"
          end
          @corr[stack.last] = idx
          @corr[idx] = stack.last
          stack.pop
        end
      end
      unless stack.empty?
        raise "unmatched ["
      end
      @count = 0
      @limit = 10_000_000
      @input = []
      @output = []
    end

    def input(a)
      if a.is_a?(String)
        @input += a.bytes
      elsif a.is_a?(Array)
        @input += a
      end
    end

    def chars(s)
      s.pack('c*').force_encoding('UTF-8')
    end

    def output
      {
        bytes: @output,
        chars: chars(@output),
      }
    end

    def info
      {
        mem: @mem,
        ptr: @ptr,
        count: @count,
      }
    end

    def inspect
      res = ""
      res << "size: #{ @code.size }\n"
      res << "input:\n"
      res << "  #{ @input.inspect }\n"
      res << "  #{ chars(@input).inspect }\n"
      res << "output:\n"
      res << "  #{ @output.inspect }\n"
      res << "  #{ chars(@output).inspect }\n"
      res << "memory:\n"
      drop_from = [@mem.rindex {|v| v != 0 } || -1, @ptr].max + 1
      mem = @mem[0...drop_from].map.with_index do |a, i|
        x = sprintf("%02X", a)
        i == @ptr ? "[#{x}]" : " #{x} "
      end
      period = 9
      head = ""
      until mem.empty?
        if head["01"] && mem[0]["00"]
          period = 33
        end
        head, *tail = mem.shift(period)
        value = 0
        tail.each_with_index do |x, i|
          if x["00"]
          elsif x["01"]
            value |= 1 << i
          else
            value = nil
            break
          end
        end
        value |= -1 << 32 if value[31] == 1
        res << "  " << ("|" + head + "|" + tail.join).gsub(/00/, "__").gsub(/ (?= )| (?=\[)|(?<=\]) /, "") << "( #{ value } )" << "\n"
      end
      res << "ptr: #{ @ptr }\n"
      res << "count: #{ @count }\n"
      res
    end

    def step
      if @count >= @limit
        raise "operation limit exceeded"
      end
      @count += 1
      @pc += 1
      case @code[@pc]
      when :inc
        @mem[@ptr] += 1
      when :dec
        @mem[@ptr] -= 1
      when :right
        @ptr += 1
      when :left
        @ptr -= 1
      when :open
        if @mem[@ptr] == 0
          @pc = @corr[@pc]
        end
      when :close
        if @mem[@ptr] != 0
          @pc = @corr[@pc]
        end
      when :get
        @mem[@ptr] = @input.shift || 0
      when :put
        @output.push(@mem[@ptr])
      when nil
        return false
      end
      if @ptr < 0
        raise "below the first cell"
      elsif @ptr == @mem.size
        @mem.push(0)
        if @ptr % 10000 === 0
          warn("beyond the #{@ptr}th cell")
        end
      else
        @mem[@ptr] &= 0xff
      end
      return true
    end

    def run
      while step
      end
      self
    end

    def self.run(code)
      new(code).run
    end
  end
end
