require "sinatra"
require "csv"

csv = CSV.read(ARGV[0], headers: true)
table = {}
csv.each do |row|
  name = row["name"]
  mode = row["mode"]
  vals = []
  row.each do |key, val|
    vals << val.to_f if key.start_with?("run")
  end
  next if vals.uniq == [0]
  table[name] ||= {}
  mean = vals.inject(&:+) / vals.size
  sd = Math.sqrt(vals.map {|v| (v - mean) * (v - mean) }.inject(&:+) / vals.size)
  case
  when mean >= 10.00 then s = "%.1f fps" % mean
  when mean >=  1.00 then s = "%.2f fps" % mean
  when mean >=  0.10 then s = "%.3f fps" % mean
  when mean >=  0.01 then s = "%.4f fps" % mean
  end
  table[name][mode] ||= [mean, [mean - sd, 0].max, mean + sd, s.dump]
end

data = []
%w(
  ruby24 ruby23 ruby22 ruby21 ruby20 ruby193 ruby187
  omrpreview
  jruby9k jruby17 rubinius mruby topaz opal
).each do |name|
  row = table[name]
  data << [name.dump, *(row["default"] || row["opt-none"]), *(row["opt-all"] || [0, "null", "null", "failure".dump])]
end

get "/" do
  @data = data.map {|row| "[#{ row.join(", ") }]" }.join(", ")
  @ticks = [0, 10, 20, 30, 40, 50, 60, 70, 80]
  erb :all
end

get "/default" do
  @data = data.map {|row| "[#{ row[0, 5].join(", ") }]" }.join(", ")
  @ticks = [0, 10, 20, 30]
  erb :default
end

get "/exit" do
  Process.kill("TERM", Process.pid)
end

__END__

@@ layout
<html>
  <head>
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
      google.load("visualization", "1", { "packages":["corechart"], callback: drawChart });
      function drawChart() {
        var data = new google.visualization.DataTable();
        <%= yield %>
        var options = {
          title: "Ruby implementation benchmark with Optcarrot",
          subtitle: "in frame per second",
          chartArea: {width: "450", height: "500"},
          width: 600,
          height: 600,
          bars: "horizontal",
          intervals: { style: "bars" },
          annotations: {
            highContrast: true,
            textStyle: { fontSize: 10, italic: true },
          },
          hAxis: {
            minValue: 0,
            ticks: <%= @ticks %>,
            title: "frame per second"
          },
          legend: { position: "bottom" }
        };
        var chart = new google.visualization.BarChart(document.getElementById("barchart"));
        google.visualization.events.addListener(chart, "ready", function () {
          console.log(chart.getImageURI());
        });
        chart.draw(data, options);
      }
    </script>
  </head>
  <body>
    <div id="barchart" style="width: 600px; height: 600px;"></div>
  </body>
</html>

@@ default
data.addColumn("string", "Ruby");
data.addColumn("number", "default mode");
data.addColumn({type: "number", role: "interval"});
data.addColumn({type: "number", role: "interval"});
data.addColumn({type: "string", role: "annotation"});
data.addRows([<%= @data %>]);

@@ all
data.addColumn("string", "Ruby");
data.addColumn("number", "default mode");
data.addColumn({type: "number", role: "interval"});
data.addColumn({type: "number", role: "interval"});
data.addColumn({type: "string", role: "annotation"});
data.addColumn("number", "optimized mode");
data.addColumn({type: "number", role: "interval"});
data.addColumn({type: "number", role: "interval"});
data.addColumn({type: "string", role: "annotation"});
data.addRows([<%= @data %>]);
