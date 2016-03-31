# rubocop:disable all

require "arduino_firmata"

class ROMReader
  D0, D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13 = [*0..13]
  A0, A1, A2, A3, A4, A5 = [*14..19]

  PIN_DATA_0     = D2
  PIN_DATA_1     = D3
  PIN_DATA_2     = D4
  PIN_DATA_3     = D5
  PIN_DATA_4     = D6
  PIN_DATA_5     = D7
  PIN_DATA_6     = D8
  PIN_DATA_7     = D9

  PIN_TS_EN      = D10
  PIN_TS_DIR     = D11

  PIN_FF_CLK     = D12
  PIN_FF0_EN     = A4
  PIN_FF1_EN     = A5

  PIN_CPU_RW     = A0
  PIN_PPU_NOT_RD = A1
  PIN_NOT_ROMSEL = A2
  PIN_M2         = A3

  Mapping = Struct.new(:data, :ff0, :ff1)
  PIN_DATA_MAPPING = {
    PIN_DATA_0 => { cpu: Mapping[0,   8, 1], ppu: Mapping[4, -13,  8] },
    PIN_DATA_1 => { cpu: Mapping[1,   9, 4], ppu: Mapping[5,   6,  7] },
    PIN_DATA_2 => { cpu: Mapping[2,  14, 0], ppu: Mapping[6,   1, 10] },
    PIN_DATA_3 => { cpu: Mapping[3,  12, 5], ppu: Mapping[3,   3,  9] },
    PIN_DATA_4 => { cpu: Mapping[4,  13, 2], ppu: Mapping[7,   2, 11] },
    PIN_DATA_5 => { cpu: Mapping[5, nil, 3], ppu: Mapping[2, nil, 13] },
    PIN_DATA_6 => { cpu: Mapping[6,  10, 6], ppu: Mapping[1,   5,  0] },
    PIN_DATA_7 => { cpu: Mapping[7,  11, 7], ppu: Mapping[0,   4, 12] },
  }

  Mode = Struct.new(:cpu_rw, :not_romsel, :m2, :ppu_not_rd)
  Modes = {
    cpu: Mode[true , false, true , true ],
    ppu: Mode[false, true , false, false],
  }

  def initialize(
    mapper: raise,
    mirroring: raise,
    prg_banks: raise,
    chr_banks: raise,
    battery: false,
    trainer: nil,
    vs_unisystem: false,
    playchoice_10: false,
    tv_system: :ntsc,
    wram_banks: 0,
    bus_conflicts: false
  )
    @prg_banks = prg_banks
    @chr_banks = chr_banks

    case mapper
    when 0
    else
      raise "unknown mapper: #{ mapper }"
    end

    case mirroring
    when :vertical   then flags_6 = 0b0001
    when :horizontal then flags_6 = 0b0001
    when :fourscreen then flags_6 = 0b1000
    else
      raise "unknown mirroring: #{ mirroring }"
    end
    flags_6 |= 1 << 1 if battery
    flags_6 |= 1 << 2 if trainer
    flags_6 |= (mapper & 0x0f) << 4

    flags_7 = 0
    flags_7 |= 1 << 0 if vs_unisystem
    flags_7 |= 1 << 1 if playchoice_10
    flags_7 |= mapper & 0xf0

    case tv_system
    when :ntsc then flags_9, flags_10 = 0, 0
    when :pal  then flags_9, flags_10 = 1, 2
    else
      raise "unknown TV system: #{ tv_system }"
    end
    flags_10 |= 1 << 4 if wram_banks > 0
    flags_10 |= 1 << 5 if bus_conflicts

    @buffer = [
      "NES\x1a",
      prg_banks,
      chr_banks,
      flags_6,
      flags_7,
      wram_banks,
      flags_9,
      flags_10,
      0,
      0,
      0,
      0,
      0,
    ].pack("A4C*")

    if trainer
      raise if trainer.bytesize != 512
      @buffer.concat(trainer)
    end

    @ard = ArduinoFirmata.connect
  end

  def run
    setup

    set_mode(:cpu)
    read_rom(0x0000, 0x4000 * @prg_banks)

    set_mode(:ppu)
    read_rom(0x0000, 0x2000 * @chr_banks)

    dump
  end

  def setup
    each_data_pin do |pin, i|
      @ard.pin_mode(pin, ArduinoFirmata::OUTPUT)
    end

    [
      PIN_TS_EN, PIN_TS_DIR, PIN_FF_CLK, PIN_FF0_EN, PIN_FF1_EN,
      PIN_CPU_RW, PIN_PPU_NOT_RD, PIN_NOT_ROMSEL, PIN_M2
    ].each do |pin|
      @ard.pin_mode(pin, ArduinoFirmata::OUTPUT)
    end

    @ard.digital_write(PIN_TS_EN , true) # Disable
    @ard.digital_write(PIN_FF0_EN, true) # Disable
    @ard.digital_write(PIN_FF1_EN, true) # Disable
    @ard.digital_write(PIN_FF_CLK, false)
    @ard.digital_write(PIN_TS_DIR, false) # input

    @ard.digital_write(PIN_CPU_RW    , false)
    @ard.digital_write(PIN_NOT_ROMSEL, false)
    @ard.digital_write(PIN_M2        , true)
    @ard.digital_write(PIN_PPU_NOT_RD, true)
  end

  def set_mode(mode)
    @mode = mode
    mode = Modes[mode]

    @ard.digital_write(PIN_CPU_RW    , mode.cpu_rw)
    @ard.digital_write(PIN_NOT_ROMSEL, mode.not_romsel)
    @ard.digital_write(PIN_M2        , mode.m2)
    @ard.digital_write(PIN_PPU_NOT_RD, mode.ppu_not_rd)
  end

  def read_rom(start, len)
    start.upto(start + len - 1) do |addr|
      # set address
      print "%s[%04x]: " % [@mode, addr]
      set_addr(PIN_FF0_EN, :ff0, addr)
      set_addr(PIN_FF1_EN, :ff1, addr)

      # read data
      byte = read_byte
      @buffer << byte
      puts "%08b" % byte
    end
  end

  def set_addr(pin_ff_en, idx, addr)
    @ard.digital_write(pin_ff_en, false) # flip-flop enable
    each_data_pin do |pin|
      i = PIN_DATA_MAPPING[pin][@mode][idx]
      v = false
      if i
        v = addr[i.abs] == 1
        v = !v if i < 0
      end
      @ard.digital_write(pin, v)
    end
    @ard.digital_write(PIN_FF_CLK, true) # latch!
    @ard.digital_write(PIN_FF_CLK, false)
    @ard.digital_write(pin_ff_en, true) # flip-flop disable
  end

  def read_byte
    each_data_pin do |pin, _i|
      @ard.pin_mode(pin, ArduinoFirmata::INPUT)
    end
    @ard.digital_write(PIN_TS_EN, false)
    sleep 1.0 / 32
    byte = 0
    each_data_pin do |pin|
      byte |= 1 << PIN_DATA_MAPPING[pin][@mode].data if @ard.digital_read(pin)
    end
    @ard.digital_write(PIN_TS_EN, true)
    each_data_pin do |pin, _i|
      @ard.pin_mode(pin, ArduinoFirmata::OUTPUT)
    end

    byte
  end

  def each_data_pin
    [
      PIN_DATA_0, PIN_DATA_1, PIN_DATA_2, PIN_DATA_3,
      PIN_DATA_4, PIN_DATA_5, PIN_DATA_6, PIN_DATA_7,
    ].each_with_index {|pin, i| yield pin, i }
  end

  def dump
    File.binwrite("tmp.nes", @buffer)
  end
end

conf = {
  mapper: 0,
  mirroring: :vertical,
  prg_banks: 2,
  chr_banks: 1,
}
ROMReader.new(conf).run

__END__

A custom "NES ROM Reader" Arduino shield (based on "Hongkong with Arduino")

Chips:

  * a: Arduino Uno
  * b: 74245 (Octal Bus Transceiver)
  * f: 74377 (Octal D Flip-flop)
  * g: 74377 (Octal D Flip-flop)
  * z: Famicom Cartridge

Pins:

  * a
    * D2..D9 (for bus)
    * D10..D12, A0..A5 (for control signals)
    * GND, 5V
  * b: b01..b20
  * f: f01..g20
  * g: g01..g20
  * z: 01..60

Connections:

  D2 --- b02 --- f03 --- g03
  D3 --- b02 --- f18 --- g18
  D4 --- b03 --- f04 --- g04
  D5 --- b04 --- f17 --- g17
  D6 --- b06 --- f07 --- g07
  D7 --- b07 --- f08 --- g08
  D8 --- b08 --- f14 --- g14
  D9 --- b09 --- f13 --- g13

  D10 --- b19 [74245 EN]
  D11 --- b01 [74245 DIR]
  D12 --- f11 [74377 CLK] --- g11 [74377 CLK]
  A0 ---- 14 [CPU R/W]
  A1 ---- 17 [PPU /RD]
  A2 ---- 44 [/ROMSEL]
  A3 ---- 32 [M2] --- 47 [PPU /WR]
  A4 ---- g01 [74377 EN]
  A5 ---- f01 [74377 EN]

  b18 --- 43 [CPU D0] ---- 60 [PPU D4]
  b17 --- 42 [CPU D1] ---- 59 [PPU D5]
  b16 --- 41 [CPU D2] ---- 58 [PPU D6]
  b15 --- 40 [CPU D3] ---- 29 [PPU D3]
  b14 --- 39 [CPU D4] ---- 57 [PPU D7]
  b13 --- 38 [CPU D5] ---- 28 [PPU D2]
  b12 --- 37 [CPU D6] ---- 27 [PPU D1]
  b11 --- 36 [CPU D7] ---- 26 [PPU D0]

  f02 --- 05 [CPU A8] ---- 49 [PPU /A13]
  f05 --- 35 [CPU A14] --- 24 [PPU A1]
  f06 --- 34 [CPU A13] --- 23 [PPU A2]
  f12 --- 02 [CPU A11] --- 21 [PPU A4]
  f15 --- 03 [CPU A10] --- 20 [PPU A5]
  f16 --- 33 [CPU A12] --- 22 [PPU A3]
  f19 --- 04 [CPU A9] ---- 19 [PPU A6]

  g02 --- 12 [CPU A1] ---- 51 [PPU A8]
  g05 --- 13 [CPU A0] ---- 53 [PPU A10]
  g06 --- 11 [CPU A2] ---- 54 [PPU A11]
  g09 --- 10 [CPU A3] ---- 56 [PPU A13]
  g12 --- 06 [CPU A7] ---- 55 [PPU A12]
  g15 --- 07 [CPU A6] ---- 25 [PPU A0]
  g16 --- 08 [CPU A5] ---- 52 [PPU A9]
  g19 --- 09 [CPU A4] ---- 50 [PPU A7]

  GND --- b10 --- f10 --- g10 --- 01
  5V  --- b20 --- f20 --- g20 --- 30 (--- 31)
