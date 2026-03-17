# rbs_inline: enabled

module Optcarrot
  # Video output driver saving a PNG file
  class PNGVideo < Video
    # @rbs @screen: Array[Array[Integer]]?

    # @rbs return: void
    # @rbs override
    def init
      super
      @palette = @palette_rgb
    end

    # @rbs return: void
    def dispose
      screen = @screen
      return unless screen && screen.size >= WIDTH * HEIGHT
      bin = PNGEncoder.new(screen, WIDTH, HEIGHT).encode
      File.binwrite(File.basename(@conf.video_output, ".EXT") + ".png", bin)
    end

    # @rbs screen: Array[Array[Integer]]
    # @rbs return: (Integer | Float)
    # @rbs override
    def tick(screen)
      @screen = screen
      super
    end

    # PNG data generator
    class PNGEncoder
      # @rbs screen: Array[Array[Integer]]
      # @rbs width: Integer
      # @rbs height: Integer
      # @rbs return: void
      def initialize(screen, width, height)
        @screen = screen #: Array[Array[Integer]]
        @width = width #: Integer
        @height = height #: Integer
      end

      # @rbs return: String
      def encode
        data = [] #: Array[Integer | Array[Integer]]
        @height.times do |y|
          data << 0
          @width.times do |x|
            data.concat(@screen[x + y * @width])
          end
        end

        [
          "\x89PNG\r\n\x1a\n".b,
          chunk("IHDR", [@width, @height, 8, 2, 0, 0, 0].pack("NNCCCCC")),
          chunk("IDAT", cheat_zlib_deflate(data)),
          chunk("IEND", ""),
        ].join
      end

      # @rbs type: String
      # @rbs data: String
      # @rbs return: String
      def chunk(type, data)
        [data.bytesize, type, data, crc32(type + data)].pack("NA4A*N")
      end

      ADLER_MOD = 65221
      # @rbs data: Array[untyped]
      # @rbs return: String
      def cheat_zlib_deflate(data)
        a = 1
        b = 0
        data.each {|d| b += a += d }
        code = [0x78, 0x9c].pack("C2") # Zlib header (RFC 1950)
        until data.empty?
          s = data.shift(0xffff)
          # cheat Deflate (RFC 1951)
          code << [data.empty? ? 1 : 0, s.size, ~s.size, *s].pack("CvvC*")
        end
        code << [b % ADLER_MOD, a % ADLER_MOD].pack("nn") # Adler-32 (RFC 1950)
      end

      CRC_TABLE = (0..255).map do |crc|
        8.times {|j| crc ^= 0x1db710641 << j if crc[j] == 1 }
        crc >> 8
      end #: Array[Integer]
      # @rbs data: String
      # @rbs return: Integer
      def crc32(data)
        crc = 0xffffffff
        data.each_byte {|v| crc = (crc >> 8) ^ CRC_TABLE[(crc & 0xff) ^ v] }
        crc ^ 0xffffffff
      end
    end
  end
end
