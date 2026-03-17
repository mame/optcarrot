# typed: true
module Optcarrot
  # Video output driver saving a PNG file
  class PNGVideo < Video
    extend T::Sig

    sig { void }
    def init
      super
      @palette = @palette_rgb
      @screen = T.let(nil, T.nilable(T::Array[T.untyped]))
    end

    sig { void }
    def dispose
      return unless @screen && T.must(@screen).size >= WIDTH * HEIGHT
      bin = PNGEncoder.new(T.must(@screen), WIDTH, HEIGHT).encode
      File.binwrite(File.basename(@conf.video_output, ".EXT") + ".png", bin)
    end

    sig { params(screen: T.untyped).returns(T.untyped) }
    def tick(screen)
      @screen = screen
      super
    end

    # PNG data generator
    class PNGEncoder
      extend T::Sig

      sig { params(screen: T::Array[T::Array[Integer]], width: Integer, height: Integer).void }
      def initialize(screen, width, height)
        @screen = T.let(screen, T::Array[T::Array[Integer]])
        @width = width
        @height = height
      end

      sig { returns(String) }
      def encode
        data = T.let([], T::Array[Integer])
        @height.times do |y|
          data << 0
          @width.times do |x|
            data.concat(T.must(@screen[x + y * @width]))
          end
        end

        [
          "\x89PNG\r\n\x1a\n".b,
          chunk("IHDR", [@width, @height, 8, 2, 0, 0, 0].pack("NNCCCCC")),
          chunk("IDAT", cheat_zlib_deflate(data)),
          chunk("IEND", ""),
        ].join
      end

      sig { params(type: String, data: String).returns(String) }
      def chunk(type, data)
        [data.bytesize, type, data, crc32(type + data)].pack("NA4A*N")
      end

      ADLER_MOD = 65221

      sig { params(data: T::Array[Integer]).returns(String) }
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

      CRC_TABLE = T.let((0..255).map do |crc|
        8.times {|j| crc ^= 0x1db710641 << j if crc[j] == 1 }
        crc >> 8
      end, T::Array[Integer])

      sig { params(data: String).returns(Integer) }
      def crc32(data)
        crc = 0xffffffff
        data.each_byte {|v| crc = (crc >> 8) ^ T.must(CRC_TABLE[(crc & 0xff) ^ v]) }
        crc ^ 0xffffffff
      end
    end
  end
end
