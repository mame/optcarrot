# rbs_inline: enabled

module Optcarrot
  # A manager class for drivers (user frontend)
  module Driver
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

    # @rbs conf: Config
    # @rbs return: [Video, Audio, Input]
    def load(conf)
      video = load_each(conf, :video, conf.video).new(conf)
      audio = load_each(conf, :audio, conf.audio).new(conf)
      input = load_each(conf, :input, conf.input).new(conf, video)
      return video, audio, input
    end

    # @rbs conf: Config
    # @rbs type: Symbol
    # @rbs name: Symbol?
    # @rbs return: untyped
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
    WIDTH = 256
    TV_WIDTH = 292
    HEIGHT = 224

    # @rbs conf: Config
    # @rbs return: void
    def initialize(conf)
      @conf = conf
      @palette_rgb = @conf.nestopia_palette ? Palette.nestopia_palette : Palette.defacto_palette
      @palette = [*0..4096] # dummy palette
      init
    end

    attr_reader :palette #: Array[Integer]

    # @rbs return: void
    def init
      @times = [] #: Array[Float]
    end

    # @rbs return: void
    def dispose
    end

    # @rbs _output: untyped
    # @rbs return: (Integer | Float)
    def tick(_output)
      @times << Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @times.shift if @times.size > 10
      @times.size < 2 ? 0 : ((@times.last - @times.first) / (@times.size - 1)) ** -1
    end

    # @rbs _scale: Integer?
    # @rbs return: void
    def change_window_size(_scale)
    end

    # @rbs _width: Integer
    # @rbs _height: Integer
    # @rbs return: void
    def on_resize(_width, _height)
    end
  end

  # A base class of audio output driver
  class Audio
    PACK_FORMAT = { 8 => "c*", 16 => "v*" }
    BUFFER_IN_FRAME = 3 # keep audio buffer during this number of frames

    # @rbs conf: Config
    # @rbs return: void
    def initialize(conf)
      @conf = conf
      @rate = conf.audio_sample_rate
      @bits = conf.audio_bit_depth
      raise "sample bits must be 8 or 16" unless @bits == 8 || @bits == 16
      @pack_format = PACK_FORMAT[@bits]

      init
    end

    # @rbs return: [Integer, Integer]
    def spec
      return @rate, @bits
    end

    # @rbs return: void
    def init
    end

    # @rbs return: void
    def dispose
    end

    # @rbs _output: untyped
    # @rbs return: void
    def tick(_output)
    end
  end

  # A base class of input driver
  class Input
    # @rbs conf: Config
    # @rbs video: Video
    # @rbs return: void
    def initialize(conf, video)
      @conf = conf
      @video = video
      init
    end

    # @rbs return: void
    def init
    end

    # @rbs return: void
    def dispose
    end

    # @rbs _frame: Integer
    # @rbs _pads: Pads
    # @rbs return: void
    def tick(_frame, _pads)
    end

    # @rbs pads: Pads
    # @rbs type: Symbol
    # @rbs code: Symbol
    # @rbs player: Integer?
    # @rbs return: void
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
