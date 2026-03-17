# rbs_inline: enabled

module Optcarrot
  # Pad pair implementation (NES has two built-in game pad.)
  class Pads
    # @rbs return: String
    def inspect
      "#<#{ self.class }>"
    end

    ###########################################################################
    # initialization

    # @rbs conf: Optcarrot::Config
    # @rbs cpu: Optcarrot::CPU
    # @rbs apu: Optcarrot::APU
    # @rbs return: void
    def initialize(conf, cpu, apu)
      @conf = conf #: Optcarrot::Config
      @cpu = cpu #: Optcarrot::CPU
      @apu = apu #: Optcarrot::APU
      @pads = [Pad.new, Pad.new] #: Array[Pad]
    end

    # @rbs return: void
    def reset
      @cpu.add_mappings(0x4016, method(:peek_401x), method(:poke_4016))
      @cpu.add_mappings(0x4017, method(:peek_401x), @apu.method(:poke_4017)) # delegate 4017H to APU
      @pads[0].reset
      @pads[1].reset
    end

    # @rbs addr: Integer
    # @rbs return: Integer
    def peek_401x(addr)
      @cpu.update
      @pads[addr - 0x4016].peek | 0x40
    end

    # @rbs _addr: Integer
    # @rbs data: Integer
    # @rbs return: void
    def poke_4016(_addr, data)
      @pads[0].poke(data)
      @pads[1].poke(data)
    end

    ###########################################################################
    # APIs

    # @rbs pad: Integer
    # @rbs btn: Integer
    # @rbs return: Integer
    def keydown(pad, btn)
      @pads[pad].buttons |= 1 << btn
    end

    # @rbs pad: Integer
    # @rbs btn: Integer
    # @rbs return: Integer
    def keyup(pad, btn)
      @pads[pad].buttons &= ~(1 << btn)
    end
  end

  ###########################################################################
  # each pad
  class Pad
    A      = 0
    B      = 1
    SELECT = 2
    START  = 3
    UP     = 4
    DOWN   = 5
    LEFT   = 6
    RIGHT  = 7

    # @rbs return: void
    def initialize
      reset
    end

    # @rbs return: void
    def reset
      @strobe = false #: bool
      @buttons = @stream = 0 #: Integer
    end

    # @rbs data: Integer
    # @rbs return: void
    def poke(data)
      prev = @strobe
      @strobe = data[0] == 1
      @stream = ((poll_state << 1) ^ -512) if prev && !@strobe
    end

    # @rbs return: Integer
    def peek
      return poll_state & 1 if @strobe
      @stream >>= 1
      return @stream[0]
    end

    # @rbs return: Integer
    def poll_state
      state = @buttons

      # prohibit impossible simultaneous keydown (right and left, up and down)
      state &= 0b11001111 if state & 0b00110000 == 0b00110000
      state &= 0b00111111 if state & 0b11000000 == 0b11000000

      state
    end

    attr_accessor :buttons #: Integer
  end
end
