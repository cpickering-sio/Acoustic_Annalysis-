# How to Create an Azigram in MATLAB
### A Beginner's Guide to Visualizing Sound Direction

---

## What is an Azigram?

An **azigram** is a visualization that shows how the **direction (azimuth)** of a sound source changes over time and frequency.

- The **x-axis** represents time
- The **y-axis** represents frequency (Hz)
- The **color** represents azimuth (compass heading in degrees) — the direction the sound is coming from

Unlike a spectrogram, which tells you *how loud* a sound is, an azigram tells you *where* a sound is coming from. It is computed from multi-channel acoustic data using the intensity of sound across different sensor axes.

Azigrams are used in ocean acoustics to track animals, ships, or other sound sources by their bearing over time.

---

## What You Need

### Multi-Channel Sensor Data

An azigram requires **at least 3 channels** of acoustic data:

| Channel | Sensor | What it records |
|---------|--------|----------------|
| Channel 1 | Omnidirectional (pressure) | Sound pressure from all directions |
| Channel 2 | X-axis (particle velocity) | Left-right directional sound |
| Channel 3 | Y-axis (particle velocity) | Front-back directional sound |

This tutorial uses a **DASAR** (Directional Autonomous Seafloor Acoustic Recorder), which records all three channels simultaneously.

---

## Step 1: Load Your Data

Your `.mat` file should contain the variable `data`, with fields:
- `data.x` — the signal matrix (rows = samples, columns = channels)
- `data.Fs` — the sample rate in Hz

```matlab
fname = "your_file.mat";
data  = load(fname);
x     = data.x;   % signal matrix: [samples x channels]
```

Use these commands in the Command Window to inspect your data before proceeding:

```matlab
whos x          % shows variable name, size, type, and memory usage
size(x)         % shows [N_samples, N_channels] — e.g., [20000, 3]
disp(data.Fs)   % sample rate in Hz
```

`whos x` is especially useful for confirming the orientation of the array — you want **rows = time samples** and **columns = channels**. If the numbers are flipped (more columns than rows), your array is transposed and you will need to fix it before passing it to `compute_directional_metrics`.

---

## Step 2: Add the Required Function to Your Path

The azigram relies on a helper function called `compute_directional_metrics.m`. You need to tell MATLAB where to find it:

```matlab
addpath '/path/to/your/deps/folder'   % folder containing compute_directional_metrics.m
```

> **Tip:** Replace the path with the actual location of `compute_directional_metrics.m` on your computer.

---

## Step 3: Set Up the Spectrogram Parameters

These parameters control the time-frequency resolution of your azigram (same as a spectrogram):

```matlab
nfft    = 256;              % FFT size — controls frequency resolution
window  = hamming(nfft);   % window function applied to each segment
noverlap = nfft / 2;        % number of overlapping samples (50% overlap)
```

> **Tip:** A larger `nfft` gives better frequency resolution but blurrier time resolution. Start with 256 and adjust.

---

## Step 4: Configure the Azigram Parameters

The `param` structure controls how direction is computed:

```matlab
metric_type{1} = 'Azimuth';   % we want compass bearing (0-360 degrees)

param.sec_avg           = '0';                    % time averaging (0 = none)
param.climm             = '[0 360]';              % color axis: full compass (0–360°)
param.brefa             = '0';                    % bearing reference angle (0 = North)
param.phase_calibration = 'Arctic5G_2014';        % calibration for your instrument
param.instrument{1}     = 'DASAR_DASAR-omnisensor';
param.instrument{2}     = 'DASAR_DASAR-Xsensor';
param.instrument{3}     = 'DASAR_DASAR-Ysensor';
```

### Key parameters explained

| Parameter | What it does |
|-----------|-------------|
| `metric_type` | What directional metric to compute — `'Azimuth'` gives compass heading |
| `param.climm` | The color axis range; `[0 360]` covers all compass directions |
| `param.brefa` | Reference angle for bearing (0 = North/up on compass) |
| `param.phase_calibration` | Corrects for phase differences between sensor channels based on instrument type |
| `param.instrument` | Tells the function which sensor type is in each channel |

---

## Step 5: Compute the Azigram

```matlab
[TT, FF, output_array, PdB] = compute_directional_metrics( ...
    x', metric_type, data.Fs, nfft, 0.5, param);
```

### What the inputs mean

| Input | Description |
|-------|-------------|
| `x'` | Signal matrix **transposed** so each row is a channel (see note below) |
| `metric_type` | Cell array of metrics to compute (e.g., `'Azimuth'`) |
| `data.Fs` | Sample rate in Hz |
| `nfft` | FFT size |
| `0.5` | Fractional overlap between windows (0.5 = 50%) |
| `param` | Parameter structure from Step 4 |

> **Why the transpose?** `compute_directional_metrics` expects the input as **[channels × samples]** — the opposite of how `data.x` is stored. Checking `size(x)` in Step 1 will confirm whether you need the `'`. If `size(x)` returns `[20000, 3]` (many rows, 3 columns), then `x'` gives `[3, 20000]` as required. If your array were already stored the other way, you would pass `x` without the `'`.

### What the outputs mean

| Output | Description |
|--------|-------------|
| `TT` | Time vector (seconds) |
| `FF` | Frequency vector (Hz) |
| `output_array{1}` | 2D grid of azimuth values [frequency × time] |
| `PdB` | Power spectral density (pressure autospectrum, in dB) |

### Sanity check: verify the spectrogram and azigram are the same size

Before plotting, confirm that the spectrogram (`Pdb`) and the azigram (`output_array{1}`) have matching dimensions. They must be the same size to be compared or overlaid:

```matlab
size(Pdb)             % size of spectrogram matrix  [frequencies × time bins]
size(output_array{1}) % size of azigram matrix       [frequencies × time bins]
```

Both should return the same two numbers. If they differ, check that you used the same `nfft` and overlap settings for both.

> **Note the capitalization:** the spectrogram uses `Pdb` (lowercase d) and the azigram output from `compute_directional_metrics` uses `PdB` (uppercase B). These are two separate variables — make sure you are checking the right one.

---

## Step 6: Plot the Azigram

```matlab
figure;
imagesc(TT, FF, output_array{1});
axis xy
colormap('jet')
colorbar
clim([0 360])                     % set color axis to full compass range
xlabel('Time (seconds)');
ylabel('Hz');
title('Azigram of the Signal');
```

> **Note:** `axis xy` flips the y-axis so low frequencies are at the bottom — this is the standard orientation.

---

## Full Example Script

```matlab
% ---- Setup ----
clear
close all
addpath '/path/to/deps'    % update this path

% ---- Load data ----
fname = "your_file.mat";
data  = load(fname);
x     = data.x;            % [samples x channels]

% ---- Spectrogram parameters ----
nfft     = 256;
window   = hamming(nfft);
noverlap = nfft / 2;

% ---- Azigram parameters ----
metric_type{1}          = 'Azimuth';
param.sec_avg           = '0';
param.climm             = '[0 360]';
param.brefa             = '0';
param.phase_calibration = 'Arctic5G_2014';
param.instrument{1}     = 'DASAR_DASAR-omnisensor';
param.instrument{2}     = 'DASAR_DASAR-Xsensor';
param.instrument{3}     = 'DASAR_DASAR-Ysensor';

% ---- Compute azigram ----
[TT, FF, output_array, PdB] = compute_directional_metrics( ...
    x', metric_type, data.Fs, nfft, 0.5, param);

% ---- Plot ----
figure;
imagesc(TT, FF, output_array{1});
axis xy
colormap('jet')
colorbar
clim([0 360])
xlabel('Time (seconds)');
ylabel('Hz');
title('Azigram of the Signal');
```

---

## Comparing the Azigram and Spectrogram Side-by-Side

You can plot both together to see *where* sounds are coming from AND *how loud* they are:

```matlab
figure;

% Spectrogram (top)
subplot(2,1,1);
[s, f, t] = spectrogram(x(:,1), window, noverlap, nfft, data.Fs);
Pdb = 10 * log10(abs(s));
imagesc(t, f, Pdb);
axis xy
colormap('jet')
colorbar
xlabel('Time (seconds)');
ylabel('Hz');
title('Spectrogram');

% Azigram (bottom)
subplot(2,1,2);
imagesc(TT, FF, output_array{1});
axis xy
colormap('jet')
colorbar
clim([0 360])
xlabel('Time (seconds)');
ylabel('Hz');
title('Azigram');
```

---

## Common Issues and Fixes

| Problem | Likely cause | Fix |
|---------|-------------|-----|
| `compute_directional_metrics` not found | Function not on MATLAB path | Run `addpath` with the correct folder path |
| All colors look the same | Color axis wrong | Check `clim([0 360])` is set after `imagesc` |
| Error about wrong number of channels | Data not transposed | Run `whos x` and `size(x)` to check orientation; pass `x'` if rows = samples |
| Output looks noisy or random | Low signal-to-noise ratio | Use `PdB` to mask low-energy pixels |
| Wrong compass directions | Wrong `brefa` or calibration | Check `param.brefa` and `param.phase_calibration` match your instrument |

---

## Further Reading

- MATLAB docs: `help imagesc` and `help spectrogram` in the Command Window
- Thode, A.M. et al. — papers on DASAR and directional acoustics in the Arctic
- Vector acoustics fundamentals: Fahy, F. *Sound Intensity* (1995)
