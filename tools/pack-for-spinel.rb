#!/usr/bin/env ruby
# Pack optcarrot into a single Ruby file for Spinel.
#
# Usage:
#   $ tools/pack-for-spinel.rb > optcarrot-single.rb
#   $ spinel optcarrot-single.rb
#   $ ./optcarrot-single

ROOT_DIR = File.expand_path("..", __dir__)
ROM = File.join(ROOT_DIR, "examples", "Lan_Master.nes")

FILES = %w[
  nes.rb
  rom.rb
  pad.rb
  cpu.rb
  apu.rb
  ppu.rb
  palette.rb
  driver.rb
  config.rb
]

FILES.each do |f|
  puts "# === #{ f } ==="
  src = File.read(File.join(ROOT_DIR, "lib/optcarrot", f), encoding: "UTF-8")
  src = src.gsub(/^[ \t]*require(_relative)?\b.*\n/, "")
  puts src
end

puts "# === bootstrap ==="
puts <<~RUBY
  def main
    argv = ["-b", "#{ ROM }"]
    i = 0; while i < ARGV.length; argv << ARGV[i]; i += 1; end
    Optcarrot::NES.new(argv).run
  end
  main
RUBY
