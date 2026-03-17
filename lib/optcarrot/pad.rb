# typed: true
module Optcarrot
  # Pad pair implementation (NES has two built-in game pad.)
  class Pads
    extend T::Sig

    sig { returns(String) }
    def inspect
      "#<#{self.class}>"
    end

    ###########################################################################
    # initialization

    sig { params(conf: Config, cpu: CPU, apu: APU).void }
    def initialize(conf, cpu, apu)
      @conf = conf
      @cpu = cpu
      @apu = apu
      @pads = [Pad.new, Pad.new]
    end

    sig { void }
    def reset
      @cpu.add_mappings(0x4016, method(:peek_401x), method(:poke_4016))
      @cpu.add_mappings(0x4017, method(:peek_401x), @apu.method(:poke_4017)) # delegate 4017H to APU
      @pads[0].reset
      @pads[1].reset
    end

    sig { params(addr: Integer).returns(Integer) }
    def peek_401x(addr)
      @cpu.update
      T.must(@pads[addr - 0x4016]).peek | 0x40
    end

    sig { params(_addr: Integer, data: Integer).void }
    def poke_4016(_addr, data)
      @pads[0].poke(data)
      @pads[1].poke(data)
    end

    ###########################################################################
    # APIs

    sig { params(pad: Integer, btn: Integer).void }
    def keydown(pad, btn)
      T.must(@pads[pad]).buttons |= 1 << btn
    end

    sig { params(pad: Integer, btn: Integer).void }
    def keyup(pad, btn)
      T.must(@pads[pad]).buttons &= ~(1 << btn)
    end
  end

  ###########################################################################
  # each pad
  class Pad
    extend T::Sig

    A      = 0
    B      = 1
    SELECT = 2
    START  = 3
    UP     = 4
    DOWN   = 5
    LEFT   = 6
    RIGHT  = 7

    sig { void }
    def initialize
      @strobe = T.let(false, T::Boolean)
      @buttons = T.let(0, Integer)
      @stream = T.let(0, Integer)
    end

    sig { void }
    def reset
      @strobe = false
      @buttons = @stream = 0
    end

    sig { params(data: Integer).void }
    def poke(data)
      prev = @strobe
      @strobe = data[0] == 1
      @stream = ((poll_state << 1) ^ -512) if prev && !@strobe
    end

    sig { returns(Integer) }
    def peek
      return poll_state & 1 if @strobe
      @stream >>= 1
      return @stream[0]
    end

    sig { returns(Integer) }
    def poll_state
      state = @buttons

      # prohibit impossible simultaneous keydown (right and left, up and down)
      state &= 0b11001111 if state & 0b00110000 == 0b00110000
      state &= 0b00111111 if state & 0b11000000 == 0b11000000

      state
    end

    sig { returns(Integer) }
    attr_accessor :buttons
  end
end
