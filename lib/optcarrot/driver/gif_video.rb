# typed: true
require_relative "misc"

module Optcarrot
  # Video output driver saving an animation GIF file
  class GIFVideo < Video
    extend T::Sig

    sig { params(conf: Config).void }
    def initialize(conf)
      @f = T.let(nil, T.nilable(File))
      @header = T.let("", String)
      super
    end

    sig { void }
    def init
      super

      @f = File.open(File.basename(@conf.video_output) + ".gif", "wb")

      @palette, colors = Driver.quantize_colors(@palette_rgb)

      # GIF Header
      header = ["GIF89a", WIDTH, HEIGHT, 0xf7, 0, 0, *colors.flatten]
      T.must(@f) << header.pack("A*vvC*")

      # Application Extension
      T.must(@f) << [0x21, 0xff, 0x0b, "NETSCAPE", "2.0", 0x03, 0x01, 0x00, 0x00].pack("C3A8A3CCvC")

      # Graphic Control Extension
      @header = [0x21, 0xf9, 0x04, 0x00, 1, 255, 0x00].pack("C4vCC")
      @header << [0x2c, 0, 0, WIDTH, HEIGHT, 0, 8].pack("Cv4C*")
    end

    sig { void }
    def dispose
      # Trailer
      T.must(@f) << [0x3b].pack("C")

      T.must(@f).close
    end

    sig { params(screen: T.untyped).returns(T.untyped) }
    def tick(screen)
      compress(screen)
      super
    end

    sig { params(data: T::Array[T.untyped]).void }
    def compress(data)
      T.must(@f) << @header

      max_code = 257
      dict = T.let((0..max_code).map {|n| T.unsafe([n, []]) }, T.untyped)

      buff = "".dup
      out = ->(code) { buff << ("%0#{max_code.bit_length}b" % code).reverse }

      cur_dict = T.let(dict, T.untyped)
      code = T.let(nil, T.untyped)
      out[256] # clear code
      data.each do |d|
        if cur_dict[d]
          code, cur_dict = T.unsafe(cur_dict[d])
        else
          out[code]
          if max_code < 4094
            max_code += 1
            cur_dict[d] = [max_code, []]
          end
          code, cur_dict = T.unsafe(dict[d])
        end
      end
      out[code]
      out[257] # end code

      buff = [buff].pack("b*")

      buff = T.must(buff).gsub(/.{1,255}/m) { [T.must($&).size].pack("C") + T.must($&) } + [0].pack("C")

      T.must(@f) << buff
    end
  end
end
