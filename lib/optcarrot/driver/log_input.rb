# typed: true
module Optcarrot
  # Input driver replaying a recorded input log
  class LogInput < Input
    extend T::Sig

    sig { params(conf: Config, video: Video).void }
    def initialize(conf, video)
      @log = T.let([], T::Array[Integer])
      @prev_state = T.let(0, Integer)
      super
    end

    sig { void }
    def init
      log_source = @conf.key_log
      if log_source.is_a?(String)
        log_data = T.cast(Marshal.load(File.binread(log_source)), T::Array[Integer])
        @log = log_data
      else
        @log = []
      end
      @prev_state = 0
    end

    sig { params(log: T::Array[Integer]).void }
    attr_writer :log

    sig { void }
    def dispose
    end

    sig { params(frame: Integer, pads: Pads).void }
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
