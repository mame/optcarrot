# Optcarrot namespace
module Optcarrot
  VERSION = "0.9.0"
end

require "rdl"
require "types/core"
require "bigdecimal"

require_relative "optcarrot/nes"
require_relative "optcarrot/rom"
require_relative "optcarrot/pad"
require_relative "optcarrot/cpu"
require_relative "optcarrot/apu"
require_relative "optcarrot/ppu"
require_relative "optcarrot/palette"
require_relative "optcarrot/driver"
require_relative "optcarrot/config"

extend RDL::Annotate
type "Optcarrot::CPU", "initialize", "(Optcarrot::Config) -> self"

RDL.do_typecheck :all
