# typed: true
# Fix for prism gem's broken RBI reference
module Prism
  class LexCompat
    class Result; end
  end
end
