task :test do
  ruby "tools/run-tests.rb"
end

task :benchmark do
  ruby "tools/run-benchmark.rb", "all", "-m", "all", "-c", "10"
end

task :wc do
  puts "lines of minimal source code:"
  sh "wc -l bin/optcarrot lib/optcarrot.rb lib/optcarrot/*.rb"
end

task :"wc-all" do
  sh "wc -l bin/optcarrot lib/optcarrot.rb lib/optcarrot/*.rb lib/optcarrot/*/*.rb"
end

task default: :test
