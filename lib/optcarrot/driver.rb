# typed: true
module Optcarrot
  # A manager class for drivers (user frontend)
  module Driver
    DRIVER_DB = T.let({
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
    }, T::Hash[Symbol, T::Hash[Symbol, Symbol]])

    extend T::Sig

    sig { params(conf: Config).returns([Video, Audio, Input]) }
    module_function def load(conf)
      video = T.unsafe(load_each(conf, :video, conf.video)).new(conf)
      audio = T.unsafe(load_each(conf, :audio, conf.audio)).new(conf)
      input = T.unsafe(load_each(conf, :input, conf.input)).new(conf, video)
      return video, audio, input
    end

    sig { params(conf: Config, type: Symbol, name: T.nilable(Symbol)).returns(T.untyped) }
    module_function def load_each(conf, type, name)
      if name
        klass = T.must(DRIVER_DB[type])[name]
        Kernel.raise "unknown #{type} driver: #{name}" unless klass
        Kernel.require_relative "driver/#{name}_#{type}" unless name == :none
        conf.debug("`#{name}' #{type} driver is selected")
        T.unsafe(Optcarrot).const_get(klass)
      else
        selected = T.let(nil, T.untyped)
        T.must(DRIVER_DB[type]).each_key do |n|
          begin
            selected = load_each(conf, type, n)
            break
          rescue LoadError
            conf.debug("fail to use `#{n}' #{type} driver")
          end
        end
        selected
      end
    end
  end

  # A base class of video output driver
  class Video
    extend T::Sig

    WIDTH = 256
    TV_WIDTH = 292
    HEIGHT = 224

    sig { params(conf: Config).void }
    def initialize(conf)
      @conf = conf
      @palette_rgb = T.let(
        @conf.nestopia_palette ? Palette.nestopia_palette : Palette.defacto_palette,
        T::Array[T.untyped]
      )
      @palette = T.let([*0..4096], T::Array[T.untyped]) # dummy palette
      @times = T.let([], T::Array[Float])
      init
    end

    sig { returns(T::Array[T.untyped]) }
    attr_reader :palette

    sig { void }
    def init
      @times = []
    end

    sig { void }
    def dispose
    end

    sig { params(_output: T.untyped).returns(T.untyped) }
    def tick(_output)
      @times << T.cast(Process.clock_gettime(Process::CLOCK_MONOTONIC), Float)
      @times.shift if @times.size > 10
      @times.size < 2 ? 0 : ((T.must(@times.last) - T.must(@times.first)) / (@times.size - 1)) ** -1
    end

    sig { params(_scale: T.nilable(Integer)).void }
    def change_window_size(_scale)
    end

    sig { params(_width: Integer, _height: Integer).void }
    def on_resize(_width, _height)
    end
  end

  # A base class of audio output driver
  class Audio
    extend T::Sig

    PACK_FORMAT = T.let({ 8 => "c*", 16 => "v*" }, T::Hash[Integer, String])
    BUFFER_IN_FRAME = 3 # keep audio buffer during this number of frames

    sig { params(conf: Config).void }
    def initialize(conf)
      @conf = conf
      @rate = T.let(conf.audio_sample_rate, Integer)
      @bits = T.let(conf.audio_bit_depth, Integer)
      raise "sample bits must be 8 or 16" unless @bits == 8 || @bits == 16
      @pack_format = T.let(T.must(PACK_FORMAT[@bits]), String)

      init
    end

    sig { returns([Integer, Integer]) }
    def spec
      return @rate, @bits
    end

    sig { void }
    def init
    end

    sig { void }
    def dispose
    end

    sig { params(_output: T.untyped).void }
    def tick(_output)
    end
  end

  # A base class of input driver
  class Input
    extend T::Sig

    sig { params(conf: Config, video: Video).void }
    def initialize(conf, video)
      @conf = conf
      @video = video
      init
    end

    sig { void }
    def init
    end

    sig { void }
    def dispose
    end

    sig { params(_frame: Integer, _pads: Pads).void }
    def tick(_frame, _pads)
    end

    sig { params(pads: Pads, type: Symbol, code: Symbol, player: T.nilable(Integer)).void }
    def event(pads, type, code, player)
      case code
      when :start  then pads.send(type, player, Pad::START)
      when :select then pads.send(type, player, Pad::SELECT)
      when :a      then pads.send(type, player, Pad::A)
      when :b      then pads.send(type, player, Pad::B)
      when :right  then pads.send(type, player, Pad::RIGHT)
      when :left   then pads.send(type, player, Pad::LEFT)
      when :down   then pads.send(type, player, Pad::DOWN)
      when :up     then pads.send(type, player, Pad::UP)
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
