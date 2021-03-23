module Optcarrot
  FOREVER_CLOCK = 0xffffffff
  RP2A03_CC = 12

  # NES emulation main
  class NES
    FPS = 60

    def initialize(conf = ARGV)
      @conf = Config.new(conf)

      @video, @audio, @input = Driver.load(@conf)

      @cpu =            CPU.new(@conf)
      @apu = @cpu.apu = APU.new(@conf, @cpu, *@audio.spec)
      @ppu = @cpu.ppu = PPU.new(@conf, @cpu, @video.palette)
      @rom  = ROM.load(@conf, @cpu, @ppu)
      @pads = Pads.new(@conf, @cpu, @apu)

      @frame = 0
      @frame_target = @conf.frames == 0 ? nil : @conf.frames
      @fps_history = [] if save_fps_history?
    end

    def inspect
      "#<#{ self.class }>"
    end

    attr_reader :fps, :video, :audio, :input, :cpu, :ppu, :apu

    def reset
      @cpu.reset
      @apu.reset
      @ppu.reset
      @rom.reset
      @pads.reset
      @cpu.boot
      @rom.load_battery
    end

    def step
      @ppu.setup_frame
      @cpu.run
      @ppu.vsync
      @apu.vsync
      @cpu.vsync
      @rom.vsync

      @input.tick(@frame, @pads)
      @fps = @video.tick(@ppu.output_pixels)
      @fps_history << @fps if save_fps_history?
      @audio.tick(@apu.output)

      @frame += 1
      @conf.info("frame #{ @frame }") if @conf.loglevel >= 2
    end

    def dispose
      if @fps
        @conf.info("fps: %.2f (in the last 10 frames)" % @fps)
        if @conf.print_fps_history
          puts "frame,fps-history"
          @fps_history.each_with_index {|fps, frame| puts "#{ frame },#{ fps }" }
        end
        if @conf.print_p95fps
          puts "p95 fps: #{@fps_history.sort[(@fps_history.length * 0.05).floor]}"
        end
        puts "fps: #{ @fps }" if @conf.print_fps
      end
      if @conf.print_video_checksum && @video.instance_of?(Video)
        puts "checksum: #{ @ppu.output_pixels.pack("C*").sum }"
      end
      @video.dispose
      @audio.dispose
      @input.dispose
      @rom.save_battery
    end

    def run
      reset

      if @conf.stackprof_mode
        require "stackprof"
        out = @conf.stackprof_output.sub("MODE", @conf.stackprof_mode)
        StackProf.start(mode: @conf.stackprof_mode.to_sym, out: out, raw: true)
      end

      step until @frame == @frame_target

      if @conf.stackprof_mode
        StackProf.stop
        StackProf.results
      end
    ensure
      dispose
    end

    private

    def save_fps_history?
      @conf.print_fps_history || @conf.print_p95fps
    end
  end
end
