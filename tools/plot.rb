require "csv"
require "pycall/import"
include PyCall::Import

pyimport "numpy", as: "np"
pyimport "pandas", as: "pd"
pyimport "matplotlib.pyplot", as: "plt"

[true, false].each do |oneshot|
  df = pd.read_csv(oneshot ? ARGV[0] : ARGV[1], index_col: ["mode", "name"])
  df = df[df.index.get_level_values(1) != "jruby9k"]
  df = df[df.index.get_level_values(1) != "jruby17"]
  df = df.filter(regex: "run \\d+").stack().to_frame("fps")
  idx = df.index.drop_duplicates
  gp = df["fps"].groupby(level: ["mode", "name"])
  (oneshot ? [true, false] : [true]).each do |summary|
    mean, std = [gp.mean(), gp.std()].map do |df_|
      df_ = df_.unstack("mode")
      df_ = df_.reindex(index: idx.get_level_values("name").unique)
      df_ = df_.reindex(columns: idx.get_level_values("mode").unique)
      df_ = df_["default"].fillna(df_["opt-none"]).to_frame if oneshot && summary
      df_
    end
    ax = mean.plot(
      kind: :barh, figsize: [8, oneshot ? summary ? 7 : 13 : 2], width: 0.8,
      xerr: std, ecolor: "lightgray", legend: !summary)
    ax.set_title(
      oneshot ?
        "Ruby implementation benchmark with Optcarrot (180 frames)"
      :
        "Start-up time (the time to show the first frame)"
    )
    ax.set_xlabel(oneshot ? "frames per second" : "seconds")
    ax.set_ylabel("")
    ax.invert_yaxis()
    texts = mean.applymap(->(v) do
      v.nan? ? "failure" : "%.#{ (2 - Math.log(v.to_f, 10)).ceil }f" % v
    end)
    ax.patches.each_with_index do |rect, i|
      x = rect.get_width() + 0.1
      y = rect.get_y() + rect.get_height() / 2
      n = PyCall.len(mean)
      text = texts.iloc[i % n, i / n]
      ax.text(x, y, text, ha: "left", va: "center")
    end
    f = oneshot ?
      summary ? "doc/benchmark-summary.png" : "doc/benchmark-full.png"
    :
      "doc/startup-time.png"
    plt.savefig(f, dpi: 80, bbox_inches: "tight")
    plt.close()
  end
end

fps_df = pd.read_csv(ARGV[2], index_col: "frame")
fps_df = fps_df[PyCall::List.new(["ruby25", "ruby20", "truffleruby", "jruby9koracle", "topaz"])]
[fps_df[1..180], fps_df].each do |df_|
  ax = df_.plot(title: "fps history (up to #{ PyCall.len(df_) } frames)", figsize: [8, 6])
  ax.set_xlabel("frames")
  ax.set_ylabel("frames per second")
  plt.savefig("doc/fps-history-#{ PyCall.len(df_) }.png", dpi: 80, bbox_inches: "tight")
  plt.close
end
