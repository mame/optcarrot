# Optcarrot ProTips&trade;
## How to install SDL2

If you are using Debian/Ubuntu, just do:

    $ sudo apt-get install libsdl2-dev

In Windows, get [`SDL2.dll`](https://www.libsdl.org/), put it into the current directory, and run Optcarrot.

## Advanced usage

### How to test Optcarrot

    $ ruby tools/run-tests.rb

### How to profile Optcarrot

You can use [stackprof](https://github.com/tmm1/stackprof).

    $ gem install stackprof
    $ bin/optcarrot --benchmark --stackprof examples/Lan_Master.nes
    $ stackprof stackprof-cpu.dump

    $ bin/optcarrot --benchmark --stackprof-mode=object examples/Lan_Master.nes
    $ stackprof stackprof-object.dump

### How to benchmark

See [`doc/benchmark.md`](benchmark.md).

### How to build gem

    $ gem build optcarrot.gemspec
    $ gem install optcarrot-*.gem

## Supported mappers

* NROM (0)
* MMC1 (1)
* UxROM (2)
* CNROM (3)
* MMC3 (4)

## Joke features
### ZIP reading

Optcarrot supports loading a ROM in a ZIP file.  `zlib` library is required.

    $ bin/optcarrot examples/alter_ego.zip

(`Optcarrot::ROM.zip_extract` in `lib/optcarrot/rom.rb` parses a ZIP file.)

### PNG/GIF/Sixel video output

    $ bin/optcarrot --video=png --video-output=foo.png -f 30 examples/Lan_Master.nes
    $ bin/optcarrot --video=gif --video-output=foo.gif -f 30 examples/Lan_Master.nes
    $ bin/optcarrot --video=sixel --audio=ao --input=term examples/Lan_Master.nes

Each encoder is implemented in `lib/optcarrot/driver/*_video.rb`.

## ROM Reader

You *must* get a commercial ROM in a legal way.  You can buy a cartridge, and read ROM data from it.  (I heard this is legal since NES cartridges are not encrypted at all, but I am not a laywer.  Do at your own risk.)

I created my own ROM reader based on ["HongKong with Arduino"](http://hongkongarduino.web.fc2.com/).  See also `tools/reader.rb`.  It requires `arduino_firmata`.

Or, there are [many interesting *free* ROMs](http://www.romhacking.net/homebrew/) that fans created.  Some of them are bundled in `examples/` directory.

## The meaning of Optcarrot

OPTimization carrot.  Ruby developers will obtain a reward (able to play NES games!) if they successfully achieve Ruby3x3.
