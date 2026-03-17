# typed: true
module Optcarrot
  # Cartridge class (with NROM mapper implemented)
  class ROM
    extend T::Sig

    MAPPER_DB = T.let({ 0x00 => self }, T::Hash[Integer, T.class_of(ROM)])

    # These are optional
    require_relative "mapper/mmc1"
    require_relative "mapper/uxrom"
    require_relative "mapper/cnrom"
    require_relative "mapper/mmc3"

    sig { params(filename: String).returns(String) }
    def self.zip_extract(filename)
      require "zlib"
      bin = File.binread(filename)
      loop do
        fields = T.must(bin.slice!(0, 30)).unpack("a4v5V3v2")
        sig_bytes = T.cast(fields[0], String)
        flags     = T.cast(fields[2], Integer)
        comp      = T.cast(fields[3], Integer)
        data_len  = T.cast(fields[7], Integer)
        fn_len    = T.cast(fields[9], Integer)
        ext_len   = T.cast(fields[10], Integer)
        break if sig_bytes != "PK\3\4".b
        fn = bin.slice!(0, fn_len)
        bin.slice!(0, ext_len)
        data = bin.slice!(0, data_len)
        next if File.extname(T.must(fn)).downcase != ".nes"
        next if T.must(flags) & 0x11 != 0
        next if comp != 0 && comp != 8
        if comp == 8
          zs = Zlib::Inflate.new(-15)
          data = zs.inflate(T.must(data))
          zs.finish
          zs.close
        end
        return T.must(data)
      end
      raise "failed to extract ROM file from `#{filename}'"
    end

    sig { params(conf: Config, cpu: CPU, ppu: PPU).returns(ROM) }
    def self.load(conf, cpu, ppu)
      filename = T.must(conf.romfile)
      basename = File.basename(filename)

      blob = (File.extname(filename) == ".zip" ? zip_extract(filename) : File.binread(filename)).bytes

      # parse mapper
      mapper = (T.must(blob[6]) >> 4) | (T.must(blob[7]) & 0xf0)

      klass = MAPPER_DB[mapper]
      raise NotImplementedError, "Unsupported mapper type 0x%02x" % mapper unless klass
      klass.new(conf, cpu, ppu, basename, blob)
    end

    class InvalidROM < StandardError
    end

    sig { params(buf: T::Array[Integer]).returns([Integer, Integer, Integer]) }
    def parse_header(buf)
      raise InvalidROM, "Missing 16-byte header" if buf.size < 16
      raise InvalidROM, "Missing 'NES' constant in header" if buf[0, 4] != "NES\x1a".bytes
      raise NotImplementedError, "trainer not supported" if T.must(buf[6])[2] == 1
      raise NotImplementedError, "VS cart not supported" if T.must(buf[7])[0] == 1
      raise NotImplementedError, "PAL not supported" unless T.must(buf[9])[0] == 0

      prg_banks = T.must(buf[4])
      chr_banks = T.must(buf[5])
      @mirroring = T.must(buf[6])[0] == 0 ? :horizontal : :vertical
      @mirroring = :four_screen if T.must(buf[6])[3] == 1
      @battery = T.must(buf[6])[1] == 1
      @mapper = (T.must(buf[6]) >> 4) | (T.must(buf[7]) & 0xf0)
      ram_banks = [1, T.must(buf[8])].max

      return prg_banks, chr_banks, ram_banks
    end

    sig { params(conf: Config, cpu: CPU, ppu: PPU, basename: String, buf: T::Array[Integer]).void }
    def initialize(conf, cpu, ppu, basename, buf)
      @conf = conf
      @cpu = cpu
      @ppu = ppu
      @basename = basename

      @mirroring = T.let(:horizontal, Symbol)
      @battery = T.let(false, T::Boolean)
      @mapper = T.let(0, Integer)
      @chr_ram = T.let(false, T::Boolean)
      @wrk_readable = T.let(false, T::Boolean)
      @wrk_writable = T.let(false, T::Boolean)

      prg_count, chr_count, wrk_count = parse_header(T.must(buf.slice!(0, 16)))

      raise InvalidROM, "EOF in ROM bank data" if buf.size < 0x4000 * prg_count
      @prg_banks = T.let((0...prg_count).map { T.must(buf.slice!(0, 0x4000)) }, T::Array[T::Array[Integer]])

      raise InvalidROM, "EOF in CHR bank data" if buf.size < 0x2000 * chr_count
      @chr_banks = T.let((0...chr_count).map { T.must(buf.slice!(0, 0x2000)) }, T::Array[T::Array[Integer]])

      @prg_ref = T.let([nil] * 0x10000, T::Array[T.nilable(Integer)])
      @prg_ref[0x8000, 0x4000] = T.must(@prg_banks.first)
      @prg_ref[0xc000, 0x4000] = T.must(@prg_banks.last)

      @chr_ram = chr_count == 0 # No CHR bank implies CHR-RAM (writable CHR bank)
      @chr_ref = T.let(@chr_ram ? [0] * 0x2000 : T.must(@chr_banks[0]).dup, T::Array[Integer])

      @wrk_readable = wrk_count > 0
      @wrk_writable = false
      @wrk = T.let(wrk_count > 0 ? (0x6000..0x7fff).map {|addr| addr >> 8 } : nil, T.nilable(T::Array[Integer]))

      init

      @ppu.nametables = @mirroring
      @ppu.set_chr_mem(@chr_ref, @chr_ram)
    end

    sig { void }
    def init
    end

    sig { void }
    def reset
      @cpu.add_mappings(0x8000..0xffff, @prg_ref, nil)
    end

    sig { returns(String) }
    def inspect
      [
        "Mapper: #{@mapper} (#{self.class.to_s.split("::").last})",
        "PRG Banks: #{@prg_banks.size}",
        "CHR Banks: #{@chr_banks.size}",
        "Mirroring: #{@mirroring}",
      ].join("\n")
    end

    sig { params(addr: Integer).returns(Integer) }
    def peek_6000(addr)
      @wrk_readable ? T.must(T.must(@wrk)[addr - 0x6000]) : (addr >> 8)
    end

    sig { params(addr: Integer, data: Integer).void }
    def poke_6000(addr, data)
      T.must(@wrk)[addr - 0x6000] = data if @wrk_writable
    end

    sig { void }
    def vsync
    end

    sig { void }
    def load_battery
      return unless @battery
      sav = @basename + ".sav"
      return unless File.readable?(sav)
      sav = File.binread(sav)
      T.must(@wrk).replace(sav.bytes)
    end

    sig { void }
    def save_battery
      return unless @battery
      sav = @basename + ".sav"
      puts "Saving: " + sav
      File.binwrite(sav, T.must(@wrk).pack("C*"))
    end
  end
end
