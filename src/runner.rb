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
    end

    def info
      {
        mem: @mem,
        ptr: @ptr,
        count: @count,
      }
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
      when :get then nil
      when :put then nil
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
      info
    end

    def self.run(code)
      new(code).run
    end
  end
end
