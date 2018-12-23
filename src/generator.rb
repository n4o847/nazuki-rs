module Nazuki
  class Generator
    def initialize
      @out = ""
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
  end
end
