# typed: true
module Optcarrot
  # UxROM mapper: http://wiki.nesdev.com/w/index.php/UxROM
  class UxROM < ROM
    extend T::Sig

    MAPPER_DB[0x02] = self

    sig { void }
    def reset
      @cpu.add_mappings(0x8000..0xffff, @prg_ref, method(:poke_8000))
    end

    sig { params(_addr: Integer, data: Integer).void }
    def poke_8000(_addr, data)
      @prg_ref[0x8000, 0x4000] = T.must(@prg_banks[data & 7])
    end
  end
end
