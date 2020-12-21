require "csv"
require "pycall/import"
include PyCall::Import

pyimport "numpy", as: "np"
pyimport "pandas", as: "pd"
pyimport "matplotlib", as: "mpl"

mpl.use("agg")

pyimport "matplotlib.pyplot", as: "plt"
pyimport "matplotlib.patches", as: "patches"
pyimport "matplotlib.path", as: "path"

if ARGV.size < 2
  puts "Usage: #$0 benchmark/...oneshot-180.csv benchmark/...oneshot-3000.csv"
end

[180, 3000].each do |frames|
  df = pd.read_csv(frames == 180 ? ARGV[0] : ARGV[1], index_col: ["mode", "name"])
  df = df.filter(regex: "run \\d+").stack().to_frame("fps")
  idx = df.index.drop_duplicates
  gp = df["fps"].groupby(level: ["mode", "name"])
  [true, false].each do |summary|
    mean, std = [gp.mean(), gp.std()].map do |df_|
      df_ = df_.unstack("mode")
      df_ = df_.reindex(index: idx.get_level_values("name").unique)
      df_ = df_.reindex(columns: idx.get_level_values("mode").unique)
      df_ = df_["default"].fillna(df_["opt-none"]).to_frame if summary
      df_
    end

    d = mean + std
    break_start = max = d.max.max.to_f.ceil(-1) + 10
    if frames == 3000
      d = mean + std
      break_start = d[d.index != "truffleruby"].max.max.to_f.ceil(-1) + 10
      d = mean - std
      break_end = d[d.index == "truffleruby"].min.min.to_f.floor(-1) - 10
    end

    gridspec_kw = {}
    gridspec_kw[:width_ratios] = [break_start, max - break_end] if frames == 3000
    fig, ax0 = plt.subplots(
      1, frames == 180 ? 1 : 2, figsize: [8, frames == 180 ? summary ? 7 : 13 : summary ? 3 : 5], sharey: "col", gridspec_kw: gridspec_kw,
    )

    if frames == 3000
      ax1 = ax0[1]
      ax0 = ax0[0]
    end

    fig.suptitle("Optcarrot, average FPS for frames #{ frames - 9 }-#{ frames }")
    fig.patch.set_facecolor("white")

    (frames == 180 ? 1 : 2).times do |i|
      mean.plot(
        ax: i == 0 ? ax0 : ax1, kind: :barh, width: 0.8,
        xerr: std, ecolor: "lightgray", legend: frames == 180 ? !summary : i == 1 && !summary,
      )
    end

    fig.subplots_adjust(wspace: 0.0, top: frames == 180 ? summary ? 0.93 : 0.96 : summary ? 0.85 : 0.90)

    if frames == 180
      ax0.set_xlim(0, max)
      ax0.set_xticks(0.step(max - 10, 10).to_a)
    else
      ax0.set_xlim(0, break_start)
      ax0.set_xticks(0.step(break_start - 10, 10).to_a)
      ax1.set_xlim(break_end, max)
      ax1.set_xticks((break_end + 10).step(max, 10).to_a)
    end

    ax0.set_xlabel("frames per second")
    ax0.set_ylabel("")
    if frames == 3000
      ax0.xaxis.get_label.set_position([(max - break_end + break_start) / 2.0 / break_start, 1])
      ax1.set_ylabel("")
      ax0.spines["right"].set_visible(false)
      ax1.spines["left"].set_visible(false)
      ax1.tick_params(axis: "y", which: "both", left: false, labelleft: false)
      ax1.invert_yaxis()
    end
    ax0.invert_yaxis()

    texts = mean.applymap(->(v) do
      v.nan? ? "failure" : "%.#{ (2 - Math.log(v.to_f, 10)).ceil }f" % v
    end)
    ax0.patches.each_with_index do |rect, i|
      x = rect.get_width() + 0.1
      y = rect.get_y() + rect.get_height() / 2
      n = PyCall.len(mean)
      text = texts.iloc[i % n, i / n]
      case
      when 0 <= x.to_f && x.to_f < break_start
        ax0.text(x, y, text, ha: "left", va: "center")
      when break_end <= x.to_f && x.to_f < max
        ax1.text(x, y, text, ha: "left", va: "center")
      end
    end

    if frames == 3000
      d1 = 0.02
      d2 = 0.1
      n = 20
      ps = (0..n).map do |i|
        x = -d1 + (1 + d1 * 2) * i / n
        y = [0, 0+d2, 0, 0-d2][i % 4]
        [y, x]
      end
      ps = path.Path.new(ps, [path.Path.MOVETO] + [path.Path.CURVE3] * n)
      line1 = patches.PathPatch.new(ps, lw: 4, edgecolor: "black", facecolor: "None", clip_on: false, transform: ax1.transAxes, zorder: 10)
      line2 = patches.PathPatch.new(ps, lw: 3, edgecolor: "white", facecolor: "None", clip_on: false, transform: ax1.transAxes, zorder: 10, capstyle: "round")
      ax1.add_patch(line1)
      ax1.add_patch(line2)
    end

    f = frames == 180 ? "" : "-3000"
    f = summary ? "doc/benchmark-summary#{ f }.png" : "doc/benchmark-full#{ f }.png"
    plt.savefig(f, dpi: 80, bbox_inches: "tight")
    plt.close()
  end
end
