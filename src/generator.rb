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
  end
end
