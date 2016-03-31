require "statsample"

rom = "examples/Lan_Master.nes"
cmd_current  = "ruby -Ilib bin/optcarrot --benchmark " + rom
cmd_original = "ruby -Ilib ../optcarrot.master/bin/optcarrot --benchmark " + rom

def measure(cmd)
  `#{ cmd }`[/fps: (\d+\.\d+)/, 1].to_f
end

current, original = [], []

puts "current\toriginal (in fps)"
(ARGV[0] || 30).to_i.times do |i|
  if i.even?
    current << measure(cmd_current)
    original << measure(cmd_original)
  else
    original << measure(cmd_original)
    current << measure(cmd_current)
  end
  puts "%2.3f\t%2.3f" % [current.last, original.last]
end

t = Statsample::Test.t_two_samples_independent(current.to_vector, original.to_vector)
p_val = t.probability_not_equal_variance

puts
puts t.summary
if p_val < 0.05
  puts "p-value is %.3f < 0.05; there IS a significant difference" % p_val
  puts "Congratulations, your optimization is confirmed!" if current.mean > original.mean
else
  puts "p-value is %.3f >= 0.05; There is NO significant differences" % p_val
end
