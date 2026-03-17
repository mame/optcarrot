# rbs_inline: enabled

module Optcarrot
  # Input driver replaying a recorded input log
  class LogInput < Input
    # @rbs return: void
    # @rbs override
    def init
      @log = @conf.key_log || [] #: Array[Integer] | String
      @log = Marshal.load(File.binread(@log)) if @log.is_a?(String)
      @prev_state = 0 #: Integer
    end

    # @rbs @log: untyped
    attr_writer :log

    # @rbs return: void
    # @rbs override
    def dispose
    end

    # @rbs frame: Integer
    # @rbs pads: Pads
    # @rbs return: void
    # @rbs override
    def tick(frame, pads)
      state = @log[frame] || 0
      [
        Pad::SELECT,
        Pad::START,
        Pad::A,
        Pad::B,
        Pad::RIGHT,
        Pad::LEFT,
        Pad::DOWN,
        Pad::UP,
      ].each do |i|
        if @prev_state[i] == 0 && state[i] == 1
          pads.keydown(0, i)
        elsif @prev_state[i] == 1 && state[i] == 0
          pads.keyup(0, i)
        end
      end
      @prev_state = state
    end
  end
end
