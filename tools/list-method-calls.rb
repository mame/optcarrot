require "ripper"

METHOD_LIST = {}
def recur(type, *args)
  if type.is_a?(Array)
    recur(*type) unless type.empty?
  elsif [:vcall, :fcall, :command_call].include?(type)
    METHOD_LIST[args[0][1]] = true
  end
  args.each do |subtree|
    recur(subtree)
  end
end
recur(*Ripper.sexp(ARGF.read))
p METHOD_LIST.keys
