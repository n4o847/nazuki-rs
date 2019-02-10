module Nazuki
  class Generator
    def initialize
      @out = ""
    end

    def optimize!(level = 1)
      case level
      when 1
        @out.gsub!(/\+\g<0>?-|-\g<0>?\+|>\g<0>?<|<\g<0>?>/, "")
      when 2
        @out.gsub!(/[+\-><]+/) do |matched|
          gen = Generator.new
          ptr = 0
          mem = Hash.new(0)
          matched.each_char do |char|
            case char
            when "+"
              mem[ptr] += 1
            when "-"
              mem[ptr] -= 1
            when ">"
              ptr += 1
            when "<"
              ptr -= 1
            end
          end
          vis = ptr >= 0 ? mem.sort : mem.sort.reverse
          qtr = 0
          vis.each do |abs, val|
            gen._right(abs - qtr)
            gen._inc(val)
            qtr = abs
          end
          gen._right(ptr - qtr)
          gen._return
        end
      end
      @out
    end

    def _raw(s)
      @out << s
    end

    def _return
      @out
    end

    def _inc(n = 1)
      while n > 0 && @out.end_with?("-")
        @out[-1] = ""
        n -= 1
      end
      while n < 0 && @out.end_with?("+")
        @out[-1] = ""
        n += 1
      end
      _raw(n.positive? ? "+" * n : "-" * -n)
    end

    def _dec(n = 1)
      _inc(-n)
    end

    def _right(n = 1)
      while n > 0 && @out.end_with?("<")
        @out[-1] = ""
        n -= 1
      end
      while n < 0 && @out.end_with?(">")
        @out[-1] = ""
        n += 1
      end
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

    def _set2(pos, val)
      _right(pos)
      _loop { _dec }
      _inc(val)
      _left(pos)
    end

    def _while(src)
      _right(src)
      _loop do
        _left(src)
        yield
        _right(src)
      end
      _left(src)
    end

    def _add(src, val)
      _right(src)
      _inc(val)
      _left(src)
    end

    def _sub(src, val)
      _right(src)
      _dec(val)
      _left(src)
    end

    # src: 転送元
    # dst_to_scl: { 転送先 => 何倍するか }
    def _move(src, dst_to_scl)
      _right(src)
      _loop do
        _dec
        _left(src)
        dst_to_scl.each do |dst, scl|
          _right(dst)
          _inc(scl)
          _left(dst)
        end
        _right(src)
      end
      _left(src)
    end

    # src: 複写元
    # tmp: 複写に使う一時メモリ
    # dst_to_scl: { 複写先 => 何倍するか }
    def _copy(src, tmp, dst_to_scl)
      _move(src, { tmp => 1 }.merge(dst_to_scl))
      _move(tmp, src => 1)
    end

    # 常に *tmp == 0 とする
    # *flg が
    #   1 なら yield(true)
    #   0 なら yield(false)
    def _branch(flg, tmp)
      _while(flg) do
        yield(true)
        _sub(tmp, 1)
        _sub(flg, 1)
      end
      _add(flg, 1)
      _add(tmp, 1)
      _while(tmp) do
        _sub(tmp, 1)
        _sub(flg, 1)
        yield(false)
      end
    end

    # 破壊的バージョン
    def _branch!(flg, tmp)
      _while(flg) do
        yield(true)
        _sub(tmp, 1)
        _sub(flg, 1)
      end
      _add(tmp, 1)
      _while(tmp) do
        _sub(tmp, 1)
        yield(false)
      end
    end

    # 呼び出した場所の左隣のセルの値が 0 であること
    # 繰り上がりに注意
    def im_inc(lsb = 0)
      _right(lsb)
      _raw("[>]+<[-<]>")
      _left(lsb)
    end

    # 呼び出した場所の左隣のセルの値が 0 であること
    # 繰り下がりに注意
    def im_dec
      _raw("-[++>-]<[<]>")
    end

    def sp_to_ip
      _left(33)
      _loop { _left(33) }
      _left(9)
      _loop { _left(9) }
    end

    def ip_to_sp
      _right(9)
      _loop { _right(9) }
      _right(33)
      _loop { _right(33) }
    end

    def main(program)

      tmp = 0
      cmd = *1..8

      ins_set = program.uniq
      if ins_set.size > 256
        raise "too large set of instructions"
      end

      _dec
      _right(9)
      program.reverse.each do |ins|
        bits = ins_set.index(ins)
        0.upto(7) do |i|
          _add(cmd[i], bits[i])
        end
        _right(9)
      end
      _left(9)
      _inc
      _while(tmp) do
        _sub(tmp, 1)
        see_bit = lambda do |i, bits|
          if i >= 0
            _branch(cmd[i], tmp) do |_| if _
              see_bit[i - 1, bits | 1 << i]
            else
              see_bit[i - 1, bits]
            end end
          else
            if ins_set[bits]
              ip_to_sp
              send(*ins_set[bits])
              sp_to_ip
            end
          end
        end
        see_bit[7, 0]
        _add(tmp, 1)
        _left(9)
        _add(tmp, 1)
      end
    end

    def ip_exit
      _left(9)
      _dec
      _right(9)
    end

    def sp_const(n)
      _inc
      32.times do |i|
        _right
        _inc(n[i])
      end
      _right
    end

    def sp_dup
      32.downto(1) do |i|
        _copy(i - 33, 0, i => 1)
      end
      _inc
      _right(33)
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
        _move(0, { -33 => 1 })
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
      _move(0, { 1 => 1 })
      _left
      _move(0, { 1 => 1 })
      29.times do
        _left
        _loop do
          _dec
          _right(2)
          _move(0, { -1 => 1 })
          _right
          im_inc
          _left(2)
          _move(0, { 1 => 1 })
          _inc
          _left
        end
      end
      _right(32)
      _set(0)
    end

    def sp_mul
      _left(33)
      _dec
      _left(33)
      _dec

      temp1 = 33
      a = *1..32, 0
      b = *34..65

      0.upto(31) do |i|
        _move(a[i], { a[i - 1] => 1 })
      end
      31.downto(0) do |i|
        _while(a[i - 1]) do
          _sub(a[i - 1], 1)
          0.upto(31 - i) do |j|
            _while(b[j]) do
              _sub(b[j], 1)
              im_inc(a[i + j])
              _set2(temp1, 0)
              _add(temp1, 1) if i != 0
            end
            _move(temp1, { b[j] => 1 }) if i != 0
            _move(a[i + j], { a[i + j - 1] => 1 }) if j != 31 - i
          end
          (31 - i).downto(0) do |j|
            _move(a[i + j - 1], { a[i + j] => 1 }) if j != 31 - i
          end
        end
      end
      31.downto(0) do |j|
        _set2(b[j], 0)
      end
      _inc
      _right(33)
    end

    def sp_not
      32.times do
        _inc
        _left
        _move(0, { 1 => -1 })
      end
      32.times do
        _right
        _move(0, { -1 => 1 })
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
          _move(0, { d => -1 })
          _right(d)
          _move(0, { -d => 1 })
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
      _move(0, { -4 => 16 })
      _left
      _move(0, { -3 => 8 })
      _left
      _move(0, { -2 => 4 })
      _left
      _move(0, { -1 => 2 })
      _left
      _loop do
        _dec
        _left(2)
        _set(0)
        31.times do
          _left
          _move(0, { 1 => 1 })
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
      _move(0, { -4 => 16 })
      _left
      _move(0, { -3 => 8 })
      _left
      _move(0, { -2 => 4 })
      _left
      _move(0, { -1 => 2 })
      _left
      _loop do
        _dec
        _left(33)
        _set(0)
        31.times do
          _right
          _move(0, { -1 => 1 })
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
      _move(0, { -4 => 16 })
      _left
      _move(0, { -3 => 8 })
      _left
      _move(0, { -2 => 4 })
      _left
      _move(0, { -1 => 2 })
      _left(2)
      _dec
      _right
      _loop do
        _dec
        _left(33)
        _set(0)
        30.times do
          _right
          _move(0, { -1 => 1 })
        end
        _right
        _move(0, { 1 => 1 })
        _right
        _move(0, { -1 => 1, -2 => 1 })
        _right
      end
      _left
    end

    def sp_flip_msb
      _inc
      _left(1)
      _move(0, { 1 => -1 })
      _right(1)
      _move(0, { -1 => 1 })
    end

    def sp_flip_msb_2
      sp_flip_msb
      _left(33)
      _dec
      sp_flip_msb
      _inc
      _right(33)
    end

    def sp_flip_lsb
      _left(32)
      _raw("[-<->]<[->+<]+>")
      _right(32)
    end

    def sp_eq
      sp_ne
      sp_flip_lsb
    end

    def sp_ne
      _left
      32.times do
        _loop do
          _dec
          _left(33)
          _dec
          _loop do
            _inc
            _right
            _inc
            _left
          end
          _right(33)
        end
        _left
      end
      _dec
      32.times do
        _loop do
          _set(0)
          _left
          _set(1)
          _right
        end
        _left
      end
      _right(32)
    end

    def sp_lt_u_or_ge_u(type)
      _left(33)
      _left(33)
      _dec
      1.upto(32) do |i|
        _right(33 + i)
        _loop do
          _dec
          _left(33)
          im_dec
          _right(33)
        end
        _left(33 + i)
        _right(i)
        _set(0)
        _left(i)
      end
      _inc
      case type
      when :lt_u
        _right(1)
        _inc
        _right(32)
        _move(0, { -32 => -1 })
      when :ge_u
        _right(33)
        _move(0, { -32 => 1 })
      else
        raise "type not specified"
      end
    end

    def sp_gt_u_or_le_u(type)
      _inc
      _left(33)
      _dec
      _left(33)
      1.upto(32) do |i|
        _right(i)
        _loop do
          _dec
          _right(33)
          im_dec
          _left(33)
        end
        _left(i)
        _right(33 + i)
        _set(0)
        _left(33 + i)
      end
      case type
      when :gt_u
        _right(1)
        _inc
        _right(65)
        _move(0, { -65 => -1 })
        _left(33)
      when :le_u
        _right(66)
        _move(0, { -65 => 1 })
        _left(33)
      else
        raise "type not specified"
      end
    end

    def sp_lt_s
      sp_flip_msb_2
      sp_lt_u
    end

    def sp_le_s
      sp_flip_msb_2
      sp_le_u
    end

    def sp_lt_u
      sp_lt_u_or_ge_u(:lt_u)
    end

    def sp_le_u
      sp_gt_u_or_le_u(:le_u)
    end

    def sp_gt_s
      sp_flip_msb_2
      sp_gt_u
    end

    def sp_ge_s
      sp_flip_msb_2
      sp_ge_u
    end

    def sp_gt_u
      sp_gt_u_or_le_u(:gt_u)
    end

    def sp_ge_u
      sp_lt_u_or_ge_u(:ge_u)
    end

    def sp_max_u_or_min_u(type)
      _left(33)
      _dec
      _left(33)

      temp1 = 33
      use_first = 67
      use_second = 68

      32.downto(1) do |i|
        keep_flag = i != 1
        _add(temp1, 1)
        _while(use_first) do
          _sub(use_first, 1)
          _sub(temp1, 1)
          _set2(33 + i, 0)
          use_first -= 1 # for optimization
          _add(use_first, 1) if keep_flag
        end
        _while(use_second) do
          _sub(use_second, 1)
          _sub(temp1, 1)
          _set2(i, 0)
          _move(33 + i, { i => 1 })
          use_second -= 1 # for optimization
          _add(use_second, 1) if keep_flag
        end
        case type
        when :max_u
          _while(temp1) do
            _while(33 + i) do # if b[i] == 1
              _sub(33 + i, 1)
              _sub(i, 1)
              _while(i) do # if a[i] == 0
                _add(i, 1)
                _add(use_second, 1) if keep_flag
              end
              _add(i, 1)
              _sub(temp1, 1)
            end
            _while(temp1) do # if b[i] == 0
              _sub(temp1, 1)
              _while(i) do # if a[i] == 1
                _sub(i, 1)
                _add(use_first, 1) if keep_flag
                _add(temp1, 1)
              end
              _move(temp1, { i => 1 })
            end
          end
        when :min_u
          _while(temp1) do
            _while(33 + i) do # if b[i] == 1
              _sub(33 + i, 1)
              _sub(i, 1)
              _while(i) do # if a[i] == 0
                _add(i, 1)
                _add(use_first, 1) if keep_flag
                _sub(temp1, 1)
              end
              _move(temp1, { i => 1 })
            end
            _while(temp1) do # if b[i] == 0
              _sub(temp1, 1)
              _while(i) do # if a[i] == 1
                _sub(i, 1)
                _add(use_second, 1) if keep_flag
              end
            end
          end
        else
          raise "type not specified"
        end
      end
      _right(33)
    end

    def sp_max_s
      sp_flip_msb_2
      sp_max_u
      sp_flip_msb
    end

    def sp_max_u
      sp_max_u_or_min_u(:max_u)
    end

    def sp_min_s
      sp_flip_msb_2
      sp_min_u
      sp_flip_msb
    end

    def sp_min_u
      sp_max_u_or_min_u(:min_u)
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
        _move(0, { flag_loop => 1 })
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
        _move(0, { 2 => 1 })
      end
      _right(2)
      _move(0, { -2 => 1 })
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
        _move(0, { -2 => 1 })
        _right
      end
      9.times do
        _move(0, { 1 => 1, 2 => 1 })
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
