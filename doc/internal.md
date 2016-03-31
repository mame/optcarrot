# Optcarrot Internal

## NES architecture

           +-CARTRIDGE--------------+
           |                        |
           |   [PRG ROM]  [CHR ROM] |
           |       |          |     |
           +-------|----------|-----+
                   |          |
           +-NES---|----------|-----+
           |       |          |     |
    audio----[APU/CPU]------[PPU]------video
           |       |          |     |
           |     [RAM]     [VRAM]   |
           |                        |
           +------------------------+

* NES
  * CPU: Central Processing unit (1.8 MHz)
  * PPU: Picture Processing Unit (5.3 MHz: CPU clock x 3)
    * Generates NTSC video output
  * APU: Audio Processing Unit (1.8 MHz)
    * Generates audio wave
  * RAM: Main memory (2 kB)
  * VRAM: Video memory (2 kB)

* Cartridge
  * PRG ROM: Program Memory
  * CHR ROM: Character Memory (dot-picture)

## Modules

### Main

* Optcarrot::NES (in lib/optcarrot/nes.rb)

This connects CPU, PPU, APU, peripherals, and frontend drivers (such as SDL2).
Stackprof is managed in this module.

### Core

* Optcarrot::CPU (in lib/optcarrot/cpu.rb)
* Optcarrot::PPU (in lib/optcarrot/ppu.rb)
* Optcarrot::APU (in lib/optcarrot/apu.rb)

These modules emulate CPU, PPU, and APU, respectively.  In principle, they does not depend on a specific frontend.

CPU and PPU have a inner class `OptimizedCodeBuilder` that creates the source code of the generated core (see later).
It parses the source code itself with assumption that the indent is sane.  So, be careful to modify the source code of CPU and PPU.

### Peripherals

* Optcarrot::Pad (in lib/optcarrot/pad.rb)

This emulates a game pad.  This module itself does not depend on a specific frontend.

* Optcarrot::ROM (in lib/optcarrot/rom.rb)

This emulates a cartridge.  Optcarrot::ROM itself emulates NROM mappers.
It is carefully designed so that other NES mappers can be defined by extending this module.
Actually `lib/optcarrot/mapper/*.rb` are defined in this way.

### Frontend

* Optcarrot::Driver (in lib/optcarrot/driver.rb)

This file includes abstract classes for user frontend.
Actual frontends are defined in `lib/optcarrot/driver/*.rb`.

A frontend consists of `Video`, `Audio`, and `Input` drivers.
Basically, a user can combine a favorite drivers.  But some drivers are tied to another specific drivers, e.g., `SFMLInput` can be used only when `SFMLVideo` is used.

* Optcarrot::Config (in lib/optcarrot/config.rb)

This serves as a configuration manager with a command-line option parser.

### Helpers

* Optcarrot::CodeOptimizationHelper (in lib/optcarrot/opt.rb)

This module provides some helper methods to manipulate source code.

* Optcarrot::Palette (in lib/optcarrot/palette.rb)

This generates a palette data.

## Two "cores" of Optcarrot

The performance bottleneck of Optcarrot is PPU emulation.  It takes about 80% of the execution time.

Optcarrot has two PPU emulation cores: the default core and the generated core.

* The default core: Slow, but its source code is (relatively) clean by using Fiber.

* The generated core: Fast, but it source code is super-dirty.
  It consists of a big while-loop that includes one case-when statement.

Casual Ruby users should write clean code. So Ruby should aim to achieve 60 fps by the default core in future.
The generated core is my play ground to research a promising approach to improve the performance of Ruby implementations.

CPU emulation is the second bottleneck.  Optcarrot also has two CPU emulation core in similar way.

## Optimized core

The generated core is dynamically generated.  Optcarrot performs the following steps at the invocation:

1. Read the source code of the default core, i.e., `s = File.read(__FILE__)`
2. Apply a series of string manipulations and generate the source code, i.e., `s = s.gsub(...)`
3. Load the generated source code, i.e., `eval(s)`

The actual generators are `PPU::OptimizedCodeBuilder` and `CPU::OptimizedCodeBuilder`.

In step 2, some optimizations, e.g., method inlining and easy pre-computation, are applied.
You can see the list of available optimizations by a command-line option `--list-opts`.

    $ bin/optcarrot --list-opts

The meanings of each optimization are shown in the last of this document.

## Optimization tuning

You can enable/disable each optimization by `--opt-ppu` and `--opt-cpu`.

    # Use the generated core with optimizations `method_inlining' and `split_show_mode' enabled
    $ bin/optcarrot --opt-ppu=method_inlining,split_show_mode ... [ROM file]

    # Use the generated core with all optimizations
    $ bin/optcarrot --opt-ppu=all [ROM file]

    # Use the generated core with all optimizations but `method_inlining'
    $ bin/optcarrot --opt-ppu=-method_inlining ... [ROM file]

    # Use the generated core with *no* optimizations
    $ bin/optcarrot --opt-ppu=none [ROM file]

Note that "the generated core with *no* optimizations" is different to "the default core".
The default core uses a Fiber, but the generated core is based on a while-loop.
The performance of them are nearly the same in MRI (but it varys in other Ruby implementations).

## Static code generation

If you want to see the actual source code of the generated core, use `--dump-ppu` or `--dump-cpu`. 

    $ bin/optcarrot --dump-ppu
    $ bin/optcarrot --opt-ppu=all --dump-ppu

You can use the dumped core by `--load-ppu` or `--load-cpu`,

    $ bin/optcarrot --dump-ppu > ppu-core.rb
    $ bin/optcarrot --load-ppu=ppu-core.rb [ROM file]

Some incomplete Ruby implementations fail to run the code generator for some reasons.
You can also use this feature in this case.

## Basic structure of the generated cores

PPU:

    def run
      while @hclk < @hclk_target
        case @hclk
        when 0 then ...
        when 1 then ...
        ...
        end
      end
    end

CPU:

    def run
      while true
        @opcode = fetch_pc
        case @opcode
        when 0x00 then ...
        when 0x01 then ...
        ...
        end
      end
    end

## method inlining

Before

    case @opcode
    when OP_AND
      fetch
      execute_and
      store
    ...
    end

After

    case @opcode
    when OP_AND
      # fetch
      @operand = @mem[@addr]

      # execute_and
      @operand &= @A

      # store
      @mem[@addr] = @operand
    ...
    end

## constant inlining

Before

    case @opcode
    when OP_AND then ...
    when OP_OR  then ...
    when OP_EOR then ...
    ...
    end

After

    case @opcode
    when 0x29 then ...
    when 0x09 then ...
    when 0x49 then ...
    ...
    end

## ivar localization

Before

    def run
      while @hclk < @hclk_target
        case @hclk
        when 0 then ...
        when 1 then ...
        ...
        end
      end
    end

After

    def run
      __hclk__ = @hclk
      __hclk_target__ = @hclk_target

      while __hclk__ < __hclk_target__
        case __hclk__
        ...
        end
      end

    ensure
      @hclk = __hclk__
      @hclk_target = __hclk_target__
    end

## split path

Before

    def run
      while @hclk < @hclk_target
        case @hclk
        when 0
	  clk_0 if @enabled
	when 1
	  clk_1 if @enabled
        ...
        end
      end
    end

After

    def run
      if @enabled
        while @hclk < @hclk_target
          case @hclk
          when 0
	    clk_0
	  when 1
	    clk_1
          ...
          end
        end
      else
        while @hclk < @hclk_target
          case @hclk
          when 0
	    # skip
	  when 1
	    # skip
          ...
          end
        end
      end
    end

## fast path

Before

    def run
      while @hclk < @hclk_target
        case @hclk
        when 0
	  clk_0
	when 1
	  clk_1
        ...
        end
      end
    end

After

    def run
      while @hclk < @hclk_target
        case @hclk
        when 0
	  if @hclk + 8 < @hclk_target
	    clk_0
	    clk_1
	    clk_2
	    clk_3
	    clk_4
	    clk_5
	    clk_6
	    clk_7
	  else
	    clk_0
	  end
	when 1
	  clk_1
        ...
        end
      end
    end

## batch render pixel (w/ fast path)

Before

    if @hclk + 8 < @hclk_target
      clk_0; render_pixel
      clk_1; render_pixel
      clk_2; render_pixel
      clk_3; render_pixel
      clk_4; render_pixel
      clk_5; render_pixel
      clk_6; render_pixel
      clk_7; render_pixel
    else
      clk_0
    end

After

    if @hclk + 8 < @hclk_target
      clk_0
      clk_1
      clk_2
      clk_3
      clk_4
      clk_5
      clk_6
      clk_7
      render_eight_pixels
    else
      clk_0
    end

## clock specialization

Before

    def run
      while @hclk < @hclk_target
        case @hclk
        when 0, 8, 16, 24, 32
          foo if @hclk = 16
	  clk_0_mod_8
        ...
        end
      end
    end

After

    def run
      while @hclk < @hclk_target
        case @hclk
        when 0, 8, 24, 32
	  clk_0_mod_8
        when 16
          foo
	  clk_0_mod_8
        ...
        end
      end
    end
