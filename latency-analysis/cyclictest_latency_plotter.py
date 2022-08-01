import matplotlib.pyplot as plt
import numpy as np
import os.path
import re
import sys

def hist_to_numbers(line):
  for i, v in enumerate(line):
    v = v.lstrip("0")
    if v == "":
      v = 0
    else:
      v = int(v)

    line[i] = v

  return line


def load_latency_hist(filename, **kwargs):
  ncols = -1
  histogram_size = 0

  with open(filename) as f:
    for line_num, line in enumerate(f):
      line = line.strip()
      if line.startswith("#"):
        continue

      if line == "":
        continue

      line = re.split(r"\s+", line)
      if ncols == -1:
        ncols = len(line)
      elif ncols != len(line):
        print(f"data is corrupted on line {line_num} as it has {len(line)} instead of the expected {ncols}: {line}")
        return

      histogram_size += 1

  data = np.empty((histogram_size, ncols), dtype=np.int64)

  idx = 0
  max_latency = -1

  with open(filename) as f:
    for line_num, line in enumerate(f):
      line = line.strip()

      # Parse the max latency
      if line.startswith("# Max Latencies"):
        line = line.split(":")[1]
        line = re.split(r"\s+", line.strip())
        hist_to_numbers(line)
        max_latency = max(line)
        continue

      # Comments, ignore
      if line.startswith("#"):
        continue

      # Empty line, ignore
      if line == "":
        continue

      line = re.split(r"\s+", line)
      hist_to_numbers(line)

      if sum(line[1:-1]) != line[-1]: # Because I used histofall for logging
        print(f"line {line_num}: last column doesn't match with the sum of the other columns")
        return

      data[idx, :] = line
      idx += 1

  kwargs["filename"] = filename
  kwargs["max"] = max_latency
  return data, kwargs

def plot_latency_hist(datas, ax=None, xlim=(0, 500)):
  if ax is None:
    fig = plt.figure()
    ax = fig.add_subplot(1, 1, 1)

  lines = []
  for data, aux_data in datas:
    l, = ax.plot(data[:, 0], data[:, 1], aux_data["style"], label=f"{aux_data['label']} (Max = {aux_data['max']}μs)")
    lines.append(l)

  ax.set_yscale("log")
  ax.set_xlim(xlim)
  ax.set_xlabel("Latency (μs)")
  ax.set_ylabel("Count")
  ax.grid()
  ax.legend(handles=lines)

def main():
  import matplotlib
  matplotlib.rcParams['font.family'] = 'Times New Roman'
  matplotlib.rcParams['mathtext.fontset'] = 'stix'
  matplotlib.rcParams['font.size'] = 12
  matplotlib.rcParams['figure.dpi'] = 200
  matplotlib.rcParams['savefig.dpi'] = 200

  datas = []
  for file in sys.argv[1:]:
    # style=None for automatic style
    data = load_latency_hist(file, label=os.path.splitext(os.path.basename(file))[0], style="")
    datas.append(data)

  fig = plt.figure()
  ax = fig.add_subplot(1, 1, 1)
  plot_latency_hist(datas, ax, xlim=[0, 400])
  fig.tight_layout()
  plt.show()

if __name__ == "__main__":
  main()
