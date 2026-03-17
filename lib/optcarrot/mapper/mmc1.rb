# typed: true
module Optcarrot
  # MMC1 mapper: http://wiki.nesdev.com/w/index.php/MMC1
  class MMC1 < ROM
    extend T::Sig

    MAPPER_DB[0x01] = self

    NMT_MODE = T.let([:first, :second, :vertical, :horizontal], T::Array[Symbol])
    PRG_MODE = T.let([:conseq, :conseq, :fix_first, :fix_last], T::Array[Symbol])
    CHR_MODE = T.let([:conseq, :noconseq], T::Array[Symbol])

    sig { params(conf: Config, cpu: CPU, ppu: PPU, basename: String, buf: T::Array[Integer]).void }
    def initialize(conf, cpu, ppu, basename, buf)
      @nmt_mode = T.let(nil, T.nilable(Symbol))
      @prg_mode = T.let(nil, T.nilable(Symbol))
      @chr_mode = T.let(nil, T.nilable(Symbol))
      @prg_bank = T.let(0, Integer)
      @chr_bank_0 = T.let(0, Integer)
      @chr_bank_1 = T.let(0, Integer)
      @shift = T.let(0, Integer)
      @shift_count = T.let(0, Integer)
      super
    end

    sig { void }
    def init
      @nmt_mode = @prg_mode = @chr_mode = nil
      @prg_bank = @chr_bank_0 = @chr_bank_1 = 0
    end

    sig { void }
    def reset
      @shift = @shift_count = 0

      @chr_banks = @chr_banks.flatten.each_slice(0x1000).to_a

      @wrk_readable = @wrk_writable = true
      @cpu.add_mappings(0x6000..0x7fff, method(:peek_6000), method(:poke_6000))
      @cpu.add_mappings(0x8000..0xffff, @prg_ref, method(:poke_prg))

      update_nmt(:horizontal)
      update_prg(:fix_last, 0, 0)
      update_chr(:conseq, 0, 0)
    end

    sig { params(addr: Integer, val: Integer).void }
    def poke_prg(addr, val)
      if val[7] == 1
        @shift = @shift_count = 0
      else
        @shift |= val[0] << @shift_count
        @shift_count += 1
        if @shift_count == 0x05
          case (addr >> 13) & 0x3
          when 0 # control
            nmt_mode = T.must(NMT_MODE[@shift      & 3])
            prg_mode = T.must(PRG_MODE[@shift >> 2 & 3])
            chr_mode = T.must(CHR_MODE[@shift >> 4 & 1])
            update_nmt(nmt_mode)
            update_prg(prg_mode, @prg_bank, @chr_bank_0)
            update_chr(chr_mode, @chr_bank_0, @chr_bank_1)
          when 1 # change chr_bank_0
            bak_chr_bank_0 = @chr_bank_0
            update_prg(@prg_mode, @prg_bank, @shift)
            @chr_bank_0 = bak_chr_bank_0
            update_chr(@chr_mode, @shift, @chr_bank_1)
          when 2 # change chr_bank_1
            update_chr(@chr_mode, @chr_bank_0, @shift)
          when 3 # change png_bank
            update_prg(@prg_mode, @shift, @chr_bank_0)
          end
          @shift = @shift_count = 0
        end
      end
    end

    sig { params(nmt_mode: Symbol).void }
    def update_nmt(nmt_mode)
      return if @nmt_mode == nmt_mode
      @nmt_mode = nmt_mode
      @ppu.nametables = @nmt_mode
    end

    sig { params(prg_mode: T.nilable(Symbol), prg_bank: Integer, chr_bank_0: Integer).void }
    def update_prg(prg_mode, prg_bank, chr_bank_0)
      return if prg_mode == @prg_mode && prg_bank == @prg_bank && chr_bank_0 == @chr_bank_0
      @prg_mode, @prg_bank, @chr_bank_0 = prg_mode, prg_bank, chr_bank_0

      high_bit = chr_bank_0 & (0x10 & (@prg_banks.size - 1))
      prg_bank_ex = ((@prg_bank & 0x0f) | high_bit) & (@prg_banks.size - 1)
      lower = T.let(0, Integer)
      upper = T.let(0, Integer)
      case @prg_mode
      when :conseq
        lower = prg_bank_ex & ~1
        upper = lower + 1
      when :fix_first
        lower = 0
        upper = prg_bank_ex
      when :fix_last
        lower = prg_bank_ex
        upper = ((@prg_banks.size - 1) & 0x0f) | high_bit
      end
      @prg_ref[0x8000, 0x4000] = T.must(@prg_banks[lower])
      @prg_ref[0xc000, 0x4000] = T.must(@prg_banks[upper])
    end

    sig { params(chr_mode: T.nilable(Symbol), chr_bank_0: Integer, chr_bank_1: Integer).void }
    def update_chr(chr_mode, chr_bank_0, chr_bank_1)
      return if chr_mode == @chr_mode && chr_bank_0 == @chr_bank_0 && chr_bank_1 == @chr_bank_1
      @chr_mode, @chr_bank_0, @chr_bank_1 = chr_mode, chr_bank_0, chr_bank_1
      return if @chr_ram

      @ppu.update(0)
      if @chr_mode == :conseq
        lower = @chr_bank_0 & 0x1e
        upper = lower + 1
      else
        lower = @chr_bank_0
        upper = @chr_bank_1
      end
      @chr_ref[0x0000, 0x1000] = T.must(@chr_banks[lower])
      @chr_ref[0x1000, 0x1000] = T.must(@chr_banks[upper])
    end
  end
end
