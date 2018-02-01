module Optcarrot
  FOREVER_CLOCK = 0xffffffff
  RP2A03_CC = 12

  # NES emulation main
  class NES
    extend RDL::Annotate
    var_type :@cpu, "Optcarrot::CPU"
    var_type :@apu, "Optcarrot::APU"
    var_type :@ppu, "Optcarrot::PPU"
    var_type :@rom, "Optcarrot::ROM"
    var_type :@pads, "Optcarrot::Pads"
    var_type :@video, "Optcarrot::Video"
    var_type :@audio, "Optcarrot::Audio"
    var_type :@input, "Optcarrot::Input"
    var_type :@frame, "Integer"
    var_type :@frame_target, "Integer or nil"
    var_type :@fps, "%real"
    var_type :@conf, "Optcarrot::Config"
    var_type :@fps_history, "Array<%real>"

    FPS = 60

    type "(?Array<String>) -> self", typecheck: :call
    def initialize(conf = RDL.type_cast(ARGV, "Array<String>", force: true))
      @conf = Config.new(conf)

      @video, @audio, @input = Driver.load(@conf)

      @cpu =            CPU.new(@conf)
      @apu = @cpu.apu = APU.new(@conf, @cpu, *@audio.spec)
      @ppu = @cpu.ppu = PPU.new(@conf, @cpu, @video.palette)
      @rom  = ROM.load(@conf, @cpu, @ppu)
      @pads = Pads.new(@conf, @cpu, @apu)

      @frame = 0
      @frame_target = @conf.frames == 0 ? nil : @conf.frames
      @fps_history = RDL.type_cast([], "Array<%real>", force: true) if @conf.print_fps_history
    end

    type "() -> String", typecheck: :call
    def inspect
      "#<#{ self.class }>"
    end

    attr_reader :fps, :video, :audio, :input, :cpu, :ppu, :apu

    type "() -> %any", typecheck: :call
    def reset
      @cpu.reset
      @apu.reset
      @ppu.reset
      @rom.reset
      @pads.reset
      @cpu.boot
      @rom.load_battery
    end

    type "() -> %any", typecheck: :call
    def step
      @ppu.setup_frame
      @cpu.run
      @ppu.vsync
      @apu.vsync
      @cpu.vsync
      @rom.vsync

      @input.tick(@frame, @pads)
      @fps = @video.tick(@ppu.output_pixels)
      @fps_history << @fps if @conf.print_fps_history
      @audio.tick(@apu.output)

      @frame += 1
      @conf.info("frame #{ @frame }") if @conf.loglevel >= 2
    end

    RDL.type :Array, :pack, '(String) -> String'

    type "() -> %any", typecheck: :call
    def dispose
      if @fps
        @conf.info("fps: %.2f (in the last 10 frames)" % @fps)
        if @conf.print_fps_history
          puts "frame,fps-history"
          @fps_history.each_with_index {|fps, frame| puts "#{ frame },#{ fps }" }
        end
        puts "fps: #{ @fps }" if @conf.print_fps
      end
      puts "checksum: #{ @ppu.output_pixels.pack("C*").sum }" if @conf.print_video_checksum && @video.class == Video
      @video.dispose
      @audio.dispose
      @input.dispose
      @rom.save_battery
    end

    require "stackprof"
    RDL.type :StackProf, "self.start", '({ mode: Symbol, out: String }) -> nil'
    RDL.type :StackProf, "self.stop", '() -> nil'
    RDL.type :StackProf, "self.results", '() -> nil'

    type "() -> %any", typecheck: :call
    def run
      reset

      if @conf.stackprof_mode
        require "stackprof"
        out = @conf.stackprof_output.sub("MODE", @conf.stackprof_mode)
        StackProf.start(mode: @conf.stackprof_mode.to_sym, out: out)
      end

      step until @frame == @frame_target

      if @conf.stackprof_mode
        StackProf.stop
        StackProf.results
      end
    ensure
      dispose
    end
  end
end
