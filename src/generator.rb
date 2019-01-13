module Nazuki
  class Generator
    def initialize
      @out = ""
    end

    def optimize!
      @out.gsub!(/\+\g<0>?-|-\g<0>?\+|>\g<0>?<|<\g<0>?>/, "")
      @out
    end

    def _raw(s)
      @out << s
    end

    def _return
      @out
    end

    def _inc(n = 1)
      _raw(n.positive? ? "+" * n : "-" * -n)
    end

    def _dec(n = 1)
      _inc(-n)
    end

    def _right(n = 1)
      _raw(n.positive? ? ">" * n : "<" * -n)
    end

    def _left(n = 1)
      _right(-n)
    end

    def _loop
      _raw("[")
      yield
      _raw("]")
    end

    def _get
      _raw(",")
    end

    def _put
      _raw(".")
    end

    def _set(n)
      _loop { _dec }
      _inc(n)
    end

    # 引数は { 相対位置 => 何倍するか } の Hash
    # 位置は変わらない
    def _move(dst)
      _loop do
        _dec
        dst.each do |p, a|
          _right(p)
          _inc(a)
          _left(p)
        end
      end
    end

    # 常に *ptr == 0 とする
    # *(ptr + flag) が
    #   1 なら yield(true)
    #   0 なら yield(false)
    def _branch(flag)
      _right(flag)
      _loop do
        _left(flag)
        yield(true)
        _dec
        _right(flag)
        _dec
      end
      _inc
      _left(flag)
      _inc
      _loop do
        _dec
        _right(flag)
        _dec
        _left(flag)
        yield(false)
      end
    end

    # 呼び出した場所の左隣のセルの値が 0 であること
    def im_inc
      _raw("[>]+<[-<]>")
    end

    def sp_const(n)
      if n & 0xffffffff != n
        warn("out of range")
      end
      _inc
      32.times do |i|
        _right
        _inc(n[i])
      end
      _right
    end

    def sp_inc
      _left(33)
      _dec
      _right
      im_inc
      _left
      _inc
      _right(33)
      _set(0)
    end

    def sp_add
      _left(33)
      _dec
      _left(33)
      32.times do
        _right
        _loop do
          _dec
          _right(33)
          im_inc
          _left(33)
        end
        _right(33)
        _move({ -33 => 1 })
        _left(33)
      end
      _right
      _right(33)
      _set(0)
      _left(33)
    end

    def sp_sub
      sp_not
      sp_inc
      sp_add
    end

    def sp_mul_10
      _left
      _set(0)
      _left
      _move({ 1 => 1 })
      _left
      _move({ 1 => 1 })
      29.times do
        _left
        _loop do
          _dec
          _right(2)
          _move({ -1 => 1 })
          _right
          im_inc
          _left(2)
          _move({ 1 => 1 })
          _inc
          _left
        end
      end
      _right(32)
      _set(0)
    end

    def sp_not
      32.times do
        _inc
        _left
        _move({ 1 => -1 })
      end
      32.times do
        _right
        _move({ -1 => 1 })
      end
      _return
    end

    def sp_and
      32.times do
        _left
        _dec
        _loop do
          _inc
          _left(33)
          _set(0)
          _right(33)
        end
      end
      _left
      _dec
    end

    def sp_or
      32.times do
        _left
        _loop do
          _dec
          _left(33)
          _set(1)
          _right(33)
        end
      end
      _left
      _dec
    end

    def sp_xor
      1.upto(32) do |i|
        d = [i, i - 33].min_by(&:abs)
        _left
        _loop do
          _dec
          _left(33)
          _move({ d => -1 })
          _right(d)
          _move({ -d => 1 })
          _inc
          _right(33 - d)
        end
      end
      _left
      _dec
    end

    def sp_shl
      27.times do
        _left
        _set(0)
      end
      _left
      _move({ -4 => 16 })
      _left
      _move({ -3 => 8 })
      _left
      _move({ -2 => 4 })
      _left
      _move({ -1 => 2 })
      _left
      _loop do
        _dec
        _left(2)
        _set(0)
        31.times do
          _left
          _move({ 1 => 1 })
        end
        _right(33)
      end
      _left
      _dec
    end

    def sp_shr_u
      27.times do
        _left
        _set(0)
      end
      _left
      _move({ -4 => 16 })
      _left
      _move({ -3 => 8 })
      _left
      _move({ -2 => 4 })
      _left
      _move({ -1 => 2 })
      _left
      _loop do
        _dec
        _left(33)
        _set(0)
        31.times do
          _right
          _move({ -1 => 1 })
        end
        _right(2)
      end
      _left
      _dec
    end

    def sp_shr_s
      27.times do
        _left
        _set(0)
      end
      _left
      _move({ -4 => 16 })
      _left
      _move({ -3 => 8 })
      _left
      _move({ -2 => 4 })
      _left
      _move({ -1 => 2 })
      _left(2)
      _dec
      _right
      _loop do
        _dec
        _left(33)
        _set(0)
        30.times do
          _right
          _move({ -1 => 1 })
        end
        _right
        _move({ 1 => 1 })
        _right
        _move({ -1 => 1, -2 => 1 })
        _right
      end
      _left
    end

    def sp_scan

      digit_value = 1
      flag_loop = 2
      flag_neg = 3

      eval_digit = lambda do
        _loop do
          9.times do
            _dec
            _right(digit_value)
            _inc
            _left(digit_value)
            _raw("[")
          end
          _set(0)
          _right(digit_value)
          _set(0)
          _left(digit_value)
          _right(flag_loop)
          _dec
          _left(flag_loop)
          9.times do
            _raw("]")
          end
        end
      end

      add_digit = lambda do
        _right(digit_value)
        _loop do
          _dec
          _left(digit_value)
          _left(32)
          im_inc
          _right(32)
          _set(0)
          _right(digit_value)
        end
        _left(digit_value)
      end

      _right(33)

      _right(flag_neg)
      _inc
      _left(flag_neg)
      _get
      _dec(45)
      _loop do
        _right(flag_neg)
        _dec
        _left(flag_neg)
        _dec(3)
        eval_digit[]
        add_digit[]
      end

      _right(flag_loop)
      _inc
      _loop do
        _left(flag_loop)
        _get
        _dec(48)
        eval_digit[]
        _right(flag_loop)
        _loop do
          _dec
          _left(flag_loop)
          sp_mul_10
          _inc
          _right(flag_loop)
        end
        _left(flag_loop)
        _move({ flag_loop => 1 })
        add_digit[]
        _right(flag_loop)
      end
      _left(flag_loop)

      _left(33)
      _inc
      _right(33)

      _right(flag_neg)
      _loop do
        _dec
        _left(flag_neg)
        sp_not
        sp_inc
        _right(flag_neg)
      end
      _left(flag_neg)

    end

    def sp_print
      # 負数用の処理 ここから
      _left
      _loop do
        _right
        _inc(45)
        _put
        _set(0)
        sp_not
        _left(33)
        _dec
        _right
        im_inc
        _left
        _inc
        _right(33)
        _left
        _move({ 2 => 1 })
      end
      _right(2)
      _move({ -2 => 1 })
      _left
      # ここまで
      _left(32)
      # 桁あふれしない正当性：
      # def check
      #   mem = []
      #   31.times do |i|
      #     digits = (2 ** i).to_s.chars.reverse.map(&:to_i)
      #     digits.each_with_index do |d, i|
      #       mem[i] ||= 0
      #       mem[i] += d
      #     end
      #   end
      #   mem.reduce(0) do |c, d|
      #     if c + d >= 256
      #       raise "overflow!!"
      #     end
      #     (c + d) / 10
      #   end
      # end
      32.times do |i|
        digits = (2 ** i).to_s.chars.reverse.map(&:to_i)
        _loop do
          _dec
          _right(32 - i)
          digits.each do |d|
            _inc(d)
            _right(3)
          end
          digits.each do
            _left(3)
          end
          _left(32 - i)
        end
        _right
      end
      9.times do
        _right
        _inc(10)
        _left
        # https://esolangs.org/wiki/Brainfuck_algorithms#Divmod_algorithm
        # >n d
        _raw("[->-[>+>>]>[+[-<+>]>+>>]<<<<<]")
        # >0 d-n%d n%d n/d
        _right
        _set(0)
        _right
        _move({ -2 => 1 })
        _right
      end
      9.times do
        _move({ 1 => 1, 2 => 1 })
        _right
        _loop do
          _loop do
            _set(0)
            _left(3)
            _inc
            _right(3)
          end
          _right
          _inc(48)
          _put
          _set(0)
          _left
        end
        _left(4)
      end
      _right
      _set(0)
      _left
      _inc(48)
      _put
      _set(0)
      _left(33)
      _dec
    end
  end
end
