require_relative "misc"

module Optcarrot
  # Video output driver using mplayer
  # Inspired from https://github.com/polmuz/pypy-image-demo/blob/master/io.py
  class MPlayerVideo < Video
    MAX_FPS = NES::FPS

    def init
      super
      @mplayer = IO.popen("mplayer -really-quiet -noframedrop -vf scale - 2>/dev/null", "wb")
      @mplayer.puts("YUV4MPEG2 W#{ WIDTH } H#{ HEIGHT } F#{ MAX_FPS }:1 Ip A#{ TV_WIDTH }:#{ WIDTH } C444")

      @palette = @palette_rgb.map do |r, g, b|
        # From https://en.wikipedia.org/wiki/YCbCr#JPEG_conversion
        y  = (+0.299    * r + 0.587    * g + 0.114    * b).to_i + 0
        cb = (-0.168736 * r - 0.331264 * g + 0.5      * b).to_i + 128
        cr = (+0.5      * r - 0.418688 * g - 0.081312 * b).to_i + 128
        [y, cr, cb]
      end
    end

    def dispose
      @mplayer.close
    end

    def tick(screen)
      @mplayer.write "FRAME\n"

      Driver.cutoff_overscan(screen)

      if @conf.show_fps && @times.size >= 2
        fps = (1.0 / (@times[-1] - @times[-2])).round
        Driver.show_fps(screen, fps, @palette) do |y, cr, cb|
          [y / 4, cr, cb]
        end
      end

      colors = screen.map {|a| a[0] } +
               screen.map {|a| a[1] } +
               screen.map {|a| a[2] }
      @mplayer.write colors.pack("C*")

      super
    end
  end
end
