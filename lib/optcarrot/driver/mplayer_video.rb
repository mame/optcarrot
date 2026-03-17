# typed: true
require_relative "misc"

module Optcarrot
  # Video output driver using mplayer
  class MPlayerVideo < Video
    extend T::Sig

    MAX_FPS = NES::FPS

    sig { params(conf: Config).void }
    def initialize(conf)
      @mplayer = T.let(nil, T.nilable(IO))
      super
    end

    sig { void }
    def init
      super
      @mplayer = IO.popen("mplayer -really-quiet -noframedrop -vf scale - 2>/dev/null", "wb")
      T.must(@mplayer).puts("YUV4MPEG2 W#{WIDTH} H#{HEIGHT} F#{MAX_FPS}:1 Ip A#{TV_WIDTH}:#{WIDTH} C444")

      @palette = @palette_rgb.map do |rgb|
        rgb = T.cast(rgb, T::Array[Integer])
        r, g, b = T.must(rgb[0]), T.must(rgb[1]), T.must(rgb[2])
        # From https://en.wikipedia.org/wiki/YCbCr#JPEG_conversion
        y  = (+0.299    * r + 0.587    * g + 0.114    * b).to_i + 0
        cb = (-0.168736 * r - 0.331264 * g + 0.5      * b).to_i + 128
        cr = (+0.5      * r - 0.418688 * g - 0.081312 * b).to_i + 128
        [y, cr, cb]
      end
    end

    sig { void }
    def dispose
      T.must(@mplayer).close
    end

    sig { params(screen: T::Array[T::Array[Integer]]).returns(T.untyped) }
    def tick(screen)
      T.must(@mplayer).write "FRAME\n"

      Driver.cutoff_overscan(screen)

      if @conf.show_fps && @times.size >= 2
        fps = (1.0 / (T.must(@times[-1]) - T.must(@times[-2]))).round
        Driver.show_fps(screen, fps, @palette) do |c|
          c = T.cast(c, T::Array[Integer])
          [T.must(c[0]) / 4, c[1], c[2]]
        end
      end

      colors = screen.map {|a| T.must(a[0]) } +
               screen.map {|a| T.must(a[1]) } +
               screen.map {|a| T.must(a[2]) }
      T.must(@mplayer).write colors.pack("C*")

      super
    end
  end
end
