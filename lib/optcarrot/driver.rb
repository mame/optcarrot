module Optcarrot
  # A manager class for drivers (user frontend)
  module Driver
    extend RDL::Annotate

    DRIVER_DB = {
      video: {
        sdl2:  :SDL2Video,
        sfml:  :SFMLVideo,
        png:   :PNGVideo,
        gif:   :GIFVideo,
        sixel: :SixelVideo,
        mplayer: :MPlayerVideo,
        none:  :Video,
      },
      audio: {
        sdl2: :SDL2Audio,
        sfml: :SFMLAudio,
        ao:   :AoAudio,
        wav:  :WAVAudio,
        none: :Audio,
      },
      input: {
        sdl2: :SDL2Input,
        sfml: :SFMLInput,
        term: :TermInput,
        log:  :LogInput,
        none: :Input,
      }
    }

    module_function

    type "self.load", "(Optcarrot::Config) -> [Optcarrot::Video, Optcarrot::Audio, Optcarrot::Input]", typecheck: :call
    def load(conf)
      video = load_each(conf, :video, conf.video).new(conf)
      audio = load_each(conf, :audio, conf.audio).new(conf)
      input = load_each(conf, :input, conf.input).new(conf, video)
      return video, audio, input
    end

    type "(Optcarrot::Config, Symbol, Symbol) -> Optcarrot::Video or Optcarrot::Audio or Optcarrot::Input", typecheck: :call
    def load_each(conf, type, name)
      if name
        klass = DRIVER_DB[type][name]
        raise "unknown #{ type } driver: #{ name }" unless klass
        require_relative "driver/#{ name }_#{ type }" unless name == :none
        conf.debug("`#{ name }' #{ type } driver is selected")
        Optcarrot.const_get(klass)
      else
        selected = nil
        DRIVER_DB[type].each_key do |n|
          begin
            selected = load_each(conf, type, n)
            break
          rescue LoadError
            conf.debug("fail to use `#{ n }' #{ type } driver")
          end
        end
        selected
      end
    end
  end

  # A base class of video output driver
  class Video
    extend RDL::Annotate

    WIDTH = 256
    TV_WIDTH = 292
    HEIGHT = 224

    var_type :@conf, "Optcarrot::Config"
    var_type :@palette_rgb, "Array"
    var_type :@times, "Array<Integer or Rational or Float>"

    type "(Optcarrot::Config) -> self", typecheck: :call
    def initialize(conf)
      @conf = conf
      @palette_rgb = @conf.nestopia_palette ? Palette.nestopia_palette : Palette.defacto_palette
      @palette = RDL.type_cast([*0..4096], "Array<Integer>", force: true) # dummy palette
      init
      self
    end

    attr_reader_type :palette, "Array<Integer>"
    attr_reader :palette

    type "() -> %any", typecheck: :call
    def init
      @times = []
    end

    type "() -> %any", typecheck: :call
    def dispose
    end

    type "(Array) -> %real", typecheck: :call
    def tick(_output)
      @times << Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @times.shift if @times.size > 10
      @times.size < 2 ? 0 : ((@times.last - @times.first) / (@times.size - 1)) ** -1
    end

    type "(%real) -> %any", typecheck: :call
    def change_window_size(_scale)
    end

    type "(%real, %real) -> %any", typecheck: :call
    def on_resize(_width, _height)
    end
  end

  # A base class of audio output driver
  class Audio
    extend RDL::Annotate

    var_type :@conf, "Optcarrot::Config"
    var_type :@rate, "Integer"
    var_type :@bits, "Integer"
    var_type :@pack_format, "String"

    PACK_FORMAT = { 8 => "c*", 16 => "v*" }
    BUFFER_IN_FRAME = 3 # keep audio buffer during this number of frames

    #type "(%real, %real) -> self", typecheck: :call
    def initialize(conf)
      @conf = conf
      @rate = conf.audio_sample_rate
      @bits = conf.audio_bit_depth
      raise "sample bits must be 8 or 16" unless @bits == 8 || @bits == 16
      @pack_format = PACK_FORMAT[@bits]

      init
    end

    type "() -> [Integer, Integer]", typecheck: :call
    def spec
      [@rate, @bits]
    end

    type "() -> %any", typecheck: :call
    def init
    end

    type "() -> %any", typecheck: :call
    def dispose
    end

    type "(Array) -> %any", typecheck: :call
    def tick(_output)
    end
  end

  # A base class of input driver
  class Input
    extend RDL::Annotate

    var_type :@conf, "Optcarrot::Config"
    var_type :@video, "Optcarrot::Video"

    #type "(Optcarrot::Config, Optcarrot::Video) -> self", typecheck: :call
    def initialize(conf, video)
      @conf = conf
      @video = video
      init
    end

    type "() -> %any", typecheck: :call
    def init
    end

    type "() -> %any", typecheck: :call
    def dispose
    end

    type "(Integer, Optcarrot::Pads) -> %any", typecheck: :call
    def tick(_frame, _pads)
    end

    type "(Optcarrot::Pads, Symbol, Symbol, Integer) -> %any", typecheck: :call
    def event(pads, type, code, player)
      case code
      when :start  then pads.send(type, player, Optcarrot::Pad::START)
      when :select then pads.send(type, player, Optcarrot::Pad::SELECT)
      when :a      then pads.send(type, player, Optcarrot::Pad::A)
      when :b      then pads.send(type, player, Optcarrot::Pad::B)
      when :right  then pads.send(type, player, Optcarrot::Pad::RIGHT)
      when :left   then pads.send(type, player, Optcarrot::Pad::LEFT)
      when :down   then pads.send(type, player, Optcarrot::Pad::DOWN)
      when :up     then pads.send(type, player, Optcarrot::Pad::UP)
      else
        return if type != :keydown
        case code
        when :screen_x1   then @video.change_window_size(1)
        when :screen_x2   then @video.change_window_size(2)
        when :screen_x3   then @video.change_window_size(3)
        when :screen_full then @video.change_window_size(nil)
        when :quit        then exit
        end
      end
    end
  end
end
