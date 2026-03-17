# typed: true

# Sorbet's built-in RBI types Numeric#step as returning Enumerator[Numeric],
# but Integer#step with Integer arguments always yields Integer values.
class Integer
  sig { params(limit: Integer, step: Integer).returns(T::Enumerator[Integer]) }
  sig { params(limit: Integer, step: Integer, blk: T.proc.params(i: Integer).void).void }
  def step(limit, step = 1, &blk); end
end
