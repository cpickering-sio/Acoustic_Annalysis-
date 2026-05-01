# Acoustic Peak Detection Tutorial
### Using Azimuth Displays to Find Sound Sources

---

## Overview

This tutorial walks through `Master_make_Directional_Analysis.m`, a script that processes DASAR recordings to detect **peaks of directional sound** — moments where a sound source is consistently coming from a specific compass bearing.

> **Note:** The peak detection approach here works for any sound source (ships, whales, geological noise, etc.). We are currently training and testing it on **fish calls**, which is why the folder and script are named accordingly. The method is general.

The workflow has four stages:
1. Compute a **spectrogram** to see sound energy over time and frequency
2. Compute an **azigram** to see sound *direction* over time and frequency
3. Build **azimuth histogram displays** to summarize directional patterns
4. Run **FastPeakFind** to automatically detect prominent peaks in those patterns

---

## What You Need

### Data
- `.mat` files, each containing a single recording
- Each file must have:
  - `data.x` — signal matrix `[samples × channels]` with at least 3 channels
  - `data.Fs` — sample rate in Hz
- Files should be organized into subdirectories ending in `00` (one per deployment station)

### Functions
- `compute_directional_metrics.m` — computes the azigram (must be on your MATLAB path)
- `FastPeakFind.m` — detects peaks in the Time Azimuth Display (included in this folder)

---

## Parameters

All parameters are set at the top of the script before the loop begins.

### Spectrogram Parameters

```matlab
nfft     = 256/2;           % FFT size (128 points); controls frequency resolution
window   = hamming(nfft);   % Hamming window reduces spectral leakage at segment edges
noverlap = nfft/2;          % 50% overlap between consecutive FFT frames
```

| Parameter | What it does |
|-----------|-------------|
| `nfft` | Larger = finer frequency resolution, coarser time resolution |
| `window` | Hamming is a standard choice; tapers the edges of each segment to zero |
| `noverlap` | 50% overlap is a good default; more overlap = smoother time axis |

### Azimuth Display & Peak Detection Parameters

```matlab
edges  = 0:15:360;                  % Azimuth histogram bin edges (15-degree bins)
thresh = (2^16)*0.2;                % Minimum value for FastPeakFind to consider a peak
filt   = fspecial('gaussian', 3,1); % Gaussian smoothing filter applied before peak detection
alg    = 1;                         % 1 = fast local maxima method, 2 = slower blob detection
```

| Parameter | What it does |
|-----------|-------------|
| `edges` | Defines the azimuth bins for the histogram displays; `0:15:360` gives 24 bins of 15° each |
| `thresh` | Peaks below this count are ignored; raise it to reduce false detections, lower it to catch weaker peaks |
| `filt` | Smooths the histogram image before peak finding so that noise doesn't create spurious peaks |
| `alg` | Algorithm 1 is faster and works well for most cases; use 2 if peaks are broad or blob-like |

---

## Step-by-Step Walkthrough

### Step 1 — Load Data and Compute the Spectrogram

The script loops over all subdirectories ending in `00`, then loops over every `.mat` file inside each one.

```matlab
data = load(fname);
x    = data.x;   % [samples × channels]

[s, f, t] = spectrogram(x(:,1), window, noverlap, nfft, data.Fs);
Pdb = 10 * log10(abs(s));   % convert to decibels
```

Only **channel 1** (the omnidirectional pressure sensor) is used for the spectrogram. This gives a standard view of sound energy over time and frequency, regardless of direction.

The result is plotted in the **top-left panel** of the figure.

---

### Step 2 — Compute the Azigram

```matlab
[TT, FF, output_array, PdB] = compute_directional_metrics(x', metric_type, ...
    data.Fs, nfft, 0.5, param);
```

This uses all 3 channels to estimate the **compass bearing** of the sound at every time-frequency bin. The result (`output_array{1}`) is a 2D matrix of azimuth values in degrees (0–360).

> **Why `x'`?** The function expects channels as rows, but `data.x` stores channels as columns. Transposing with `'` flips the orientation.

The azigram is plotted in the **bottom-left panel** using an `hsv` colormap, where each color represents a compass direction.

---

### Step 3 — Frequency Azimuth Display

```matlab
Ncounts_fraz = zeros(length(FF), length(edges)-1);
for Ifreq = 1:length(FF)
    aziline = output_array{1}(Ifreq,:);
    [Ncounts_fraz(Ifreq,:), edges] = histcounts(aziline, edges);
end
Ncounts_fraz = Ncounts_fraz / length(TT);
```

For each frequency bin, this counts how often the sound came from each azimuth direction across all time steps. Dividing by `length(TT)` normalizes by the number of time bins so values represent a **fraction of time** rather than raw counts.

The result is plotted in the **top-right panel**: frequency on the y-axis, heading on the x-axis. A bright stripe at a particular heading means sound at that frequency consistently came from that direction.

---

### Step 4 — Time Azimuth Display

```matlab
Ncounts_taz = zeros(length(edges)-1, length(TT));
for Itime = 1:length(TT)
    aziline = output_array{1}(:,Itime);
    [Ncounts_taz(:,Itime), edges] = histcounts(aziline, edges);
end
Ncounts_taz = Ncounts_taz / length(FF);
```

Same idea, but now for each **time bin** across all frequencies. The result shows how often each compass direction appeared at each moment in time, normalized by the number of frequency bins.

The result is plotted in the **bottom-right panel**: heading on the x-axis, time on the y-axis. A bright dot or stripe at a particular time and heading means a sound source was detected from that direction at that moment. The color axis is capped at `0.3` — if most frequency bins are pointing the same direction, that's a strong, consistent signal.

This panel is the input to peak detection in Step 5.

---

### Step 5 — Peak Detection with FastPeakFind

After all `.mat` files in a subdirectory are processed, FastPeakFind searches the **Time Azimuth Display** for peaks:

```matlab
[cent, cm] = FastPeakFind(Ncounts_taz', thresh, filt, edge, alg);
azi_pick   = midpoint(round(cent(1:2:end)));   % azimuth of each peak (degrees)
t_pick     = TT(round(cent(2:2:end)));         % time of each peak (seconds)
```

Peaks are returned as `(x, y)` pairs interleaved in `cent`: odd indices are azimuth positions, even indices are time positions. These are then converted back to physical units (degrees and seconds) and plotted as **red circles** on the Time Azimuth Display.

> **What counts as a peak?** A peak is a local maximum that is above `thresh` after smoothing with `filt`. Only values above the threshold survive; everything else is zeroed out before the search begins.

#### FastPeakFind Processing Stages (Debug Mode)

When `plot_debug_output = true` inside `FastPeakFind.m`, a separate figure (figure 100) shows the image at four stages:

| Stage | What you see |
|-------|-------------|
| 1 — After integer conversion | Raw histogram image cast to uint16 |
| 2 — After median filter step | (Currently skipped; medfilt2 is commented out) |
| 3 — After thresholding | Values below `thresh` zeroed out |
| 4 — After Gaussian smoothing | Final smoothed image that peaks are found in |

This is useful for diagnosing missed or false peaks. Set `plot_debug_output = false` to suppress these plots during normal use.

---

## Reading the Output

After running, each figure has four panels:

```
┌─────────────────┬──────────────────────────┐
│   Spectrogram   │  Frequency Azimuth       │
│  (energy vs     │  Display                 │
│  time & freq)   │  (freq vs heading)       │
├─────────────────┼──────────────────────────┤
│   Azigram       │  Time Azimuth Display    │
│  (direction vs  │  (time vs heading)       │
│  time & freq)   │  + red peak markers      │
└─────────────────┴──────────────────────────┘
```

A **red circle** on the Time Azimuth Display marks a detected peak: a moment in time when sound was strongly and consistently coming from a particular compass bearing across multiple frequencies. These are your candidate sound source detections.

---

## Tuning the Detection

If you are getting too many false detections:
- Raise `thresh` to require stronger peaks
- Increase the Gaussian filter size in `filt` to smooth out more noise

If you are missing real events:
- Lower `thresh`
- Check the debug plots in figure 100 to see whether the event survives thresholding

If peaks are detected at the wrong time or heading:
- Check `param.brefa` (bearing reference angle) and `param.phase_calibration` match your instrument
- Verify `edges` covers the full 0–360° range with appropriate bin width

---

## Common Issues

| Problem | Likely cause | Fix |
|---------|-------------|-----|
| No red circles appear | `thresh` too high, or no strong peaks exist | Lower `thresh` or check debug figure 100 |
| Too many red circles | `thresh` too low or image too noisy | Raise `thresh` or increase smoothing in `filt` |
| `compute_directional_metrics` not found | Function not on MATLAB path | Add `addpath` pointing to the folder containing it |
| Azigram looks like random noise | Low SNR or wrong calibration | Check `param.phase_calibration` matches your DASAR unit |
| Figure 100 appears unexpectedly | Debug mode is on | Set `plot_debug_output = false` in `FastPeakFind.m` |
