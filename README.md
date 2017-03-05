# Optcarrot: A NES Emulator for Ruby Benchmark

## Project Goals

This project aims to provide an "enjoyable" benchmark for Ruby implementation to drive ["Ruby3x3: Ruby 3 will be 3 times faster"][ruby3x3].

The specific target is a NES (Nintendo Entertainment System) emulator that works at *20 fps* in Ruby 2.0.  An original NES works at 60 fps.  If Ruby3x3 is succeeded, we can enjoy a NES game with Ruby!

NOTE: We do *not* aim to create a practical NES emulator.  There have been already many great emulators available.  We recommend you use another emulator if you just want to play a game.

## Basic usage

SDL2 is required.

    $ git clone http://github.com/mame/optcarrot.git
    $ cd optcarrot
    $ bin/optcarrot examples/Lan_Master.nes

|key   |button       |
|------|-------------|
|arrow |D-pad        |
|`Z`   |A button     |
|`X`   |B button     |
|space |Start button |
|return|Select button|

See [`doc/bonus.md`](doc/bonus.md) for advanced usage.

## Benchmark example

![benchmark chart](doc/benchmark-default.png)

See [`doc/benchmark.md`](doc/benchmark.md) for the measurement condition.

See also [Ruby Releases Benchmarks](https://rubybench.org/ruby/ruby/releases?result_type=Optcarrot%20Lan_Master.nes) and [Ruby Commits Benchmarks](https://rubybench.org/ruby/ruby/commits?result_type=Optcarrot%20Lan_Master.nes&display_count=2000) for the continuous benchmark results.

You may also want to read [@eregon's great post](https://eregon.me/blog/2016/11/28/optcarrot.html) for JRuby+Truffle potential performance after warm-up.

## Optimized mode

It may run faster with the option `--opt`.

    $ bin/optcarrot --opt examples/Lan_Master.nes

This option will generate an optimized (and super-dirty) Ruby code internally, and replace some bottleneck methods with them.  See [`doc/internal.md`](doc/internal.md) in detail.

## See also

* [Slide deck](http://www.slideshare.net/mametter/optcarrot-a-pureruby-nes-emulator) ([Tokyo RubyKaigi 11](http://regional.rubykaigi.org/tokyo11/en/))

## Acknowledgement

We appreciate all the people who devoted efforts to NES analysis.  If it had not been not for the [NESdev Wiki][nesdev-wiki], we could not create this program.  We also read the source code of Nestopia, NESICIDE, and others.  We used the test ROMs due to NESICIDE.

[ruby3x3]: https://www.youtube.com/watch?v=LE0g2TUsJ4U&t=3248
[nesdev-wiki]: http://wiki.nesdev.com/w/index.php/NES_reference_guide
