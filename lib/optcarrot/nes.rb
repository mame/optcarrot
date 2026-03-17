# typed: true
module Optcarrot
  FOREVER_CLOCK = 0xffffffff
  RP2A03_CC = 12

  # NES emulation main
  class NES
    extend T::Sig

    FPS = 60

    sig { params(conf: T.untyped).void }
    def initialize(conf = ARGV)
      @conf = T.let(Config.new(conf), Config)

      @video, @audio, @input = T.let(Driver.load(@conf), [Video, Audio, Input])

      @cpu = T.let(CPU.new(@conf), CPU)
      @apu = T.let(APU.new(@conf, @cpu, *@audio.spec), APU)
      @cpu.apu = @apu
      @ppu = T.let(PPU.new(@conf, @cpu, @video.palette), PPU)
      @cpu.ppu = @ppu
      @rom = T.let(ROM.load(@conf, @cpu, @ppu), ROM)
      @pads = T.let(Pads.new(@conf, @cpu, @apu), Pads)

      @frame = T.let(0, Integer)
      @frame_target = T.let(@conf.frames == 0 ? nil : @conf.frames, T.nilable(Integer))
      @fps = T.let(nil, T.nilable(T.any(Integer, Float)))
      @fps_history = T.let(save_fps_history? ? [] : nil, T.nilable(T::Array[T.any(Integer, Float)]))
    end

    sig { returns(String) }
    def inspect
      "#<#{self.class}>"
    end

    sig { returns(T.nilable(T.any(Integer, Float))) }
    attr_reader :fps

    sig { returns(Video) }
    attr_reader :video

    sig { returns(Audio) }
    attr_reader :audio

    sig { returns(Input) }
    attr_reader :input

    sig { returns(CPU) }
    attr_reader :cpu

    sig { returns(PPU) }
    attr_reader :ppu

    sig { returns(APU) }
    attr_reader :apu

    sig { void }
    def reset
      @cpu.reset
      @apu.reset
      @ppu.reset
      @rom.reset
      @pads.reset
      @cpu.boot
      @rom.load_battery
    end

    sig { void }
    def step
      @ppu.setup_frame
      @cpu.run
      @ppu.vsync
      @apu.vsync
      @cpu.vsync
      @rom.vsync

      @input.tick(@frame, @pads)
      @fps = @video.tick(@ppu.output_pixels)
      @fps_history << @fps if @fps_history
      @audio.tick(@apu.output)

      @frame += 1
      @conf.info("frame #{@frame}") if @conf.loglevel >= 2
    end

    sig { void }
    def dispose
      if @fps
        @conf.info("fps: %.2f (in the last 10 frames)" % @fps)
        if @conf.print_fps_history && @fps_history
          puts "frame,fps-history"
          @fps_history.each_with_index {|fps, frame| puts "#{frame},#{fps}" }
        end
        if @conf.print_p95fps && @fps_history
          puts "p95 fps: #{@fps_history.sort[(@fps_history.length * 0.05).floor]}"
        end
        puts "fps: #{@fps}" if @conf.print_fps
      end
      if @conf.print_video_checksum && @video.instance_of?(Video)
        puts "checksum: #{@ppu.output_pixels.pack("C*").sum}"
      end
      @video.dispose
      @audio.dispose
      @input.dispose
      @rom.save_battery
      @ppu.dispose
    end

    sig { void }
    def run
      reset

      if @conf.stackprof_mode
        require "stackprof"
        stackprof = T.unsafe(Object.const_get(:StackProf))
        out = T.must(@conf.stackprof_mode)
        out = @conf.stackprof_output.sub("MODE", out)
        stackprof.start(mode: T.must(@conf.stackprof_mode).to_sym, out: out, raw: true)
      end

      step until @frame == @frame_target

      if @conf.stackprof_mode
        stackprof = T.unsafe(Object.const_get(:StackProf))
        stackprof.stop
        stackprof.results
      end
    ensure
      dispose
    end

    private

    sig { returns(T::Boolean) }
    def save_fps_history?
      @conf.print_fps_history || @conf.print_p95fps
    end
  end
end
