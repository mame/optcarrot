# typed: true
module Optcarrot
  # CNROM mapper: http://wiki.nesdev.com/w/index.php/CNROM
  class CNROM < ROM
    extend T::Sig

    MAPPER_DB[0x03] = self

    sig { void }
    def reset
      @cpu.add_mappings(0x8000..0xffff, @prg_ref, @chr_ram ? nil : method(:poke_8000))
    end

    sig { params(_addr: Integer, data: Integer).void }
    def poke_8000(_addr, data)
      @chr_ref.replace(T.must(@chr_banks[data & 3]))
    end
  end
end
