# typed: true

# Sorbet's built-in RBI for Fiber doesn't declare that `new` takes a block.
class Fiber
  sig { params(blk: T.proc.returns(T.untyped)).void }
  def initialize(&blk); end
end
