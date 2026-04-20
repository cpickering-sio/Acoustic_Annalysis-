# How to Create a Spectrogram in MATLAB
### A Beginner's Guide to Visualizing Sound

---

## What is a Spectrogram?

A **spectrogram** is a visual representation of how the frequency content of a sound changes over time.

- The **x-axis** represents time
- The **y-axis** represents frequency (pitch)
- The **color** represents amplitude (loudness) — brighter = louder

Spectrograms are used in bioacoustics, speech analysis, music, and ocean acoustics to "see" sounds that would otherwise just be waveforms.

---

## Step 1: Understand Your Audio Data

Before making a spectrogram, know the basics of your audio file:

| Term | What it means |
|------|--------------|
| **Sample rate (Fs)** | How many data points per second (e.g., 44100 Hz for CD quality) |
| **Duration** | Total length of the recording in seconds |
| **Channels** | Mono (1) or stereo (2) |

You can check these in MATLAB after loading your file:

```matlab
[x, Fs] = audioread('your_file.wav');
disp(size(x))   % rows = samples, columns = channels
disp(Fs)        % sample rate in Hz
```

---

## Step 2: Load Your Audio File

```matlab
% Load the audio file
[x, Fs] = audioread('your_file.wav');

% If stereo, take just one channel
x = x(:, 1);
```

> **Tip:** MATLAB's `audioread` works with `.wav`, `.mp3`, `.flac`, and more.

---

## Step 3: Choose Your Spectrogram Parameters

These three parameters control how your spectrogram looks and what detail it shows:

### Window Length (`window`)
- Determines the **time resolution** vs. **frequency resolution** tradeoff
- **Longer window** = better frequency detail, blurrier time detail
- **Shorter window** = sharper time detail, blurrier frequency detail
- A good starting point: `window = Fs * 0.1` (100 ms window)

```matlab
window = round(Fs * 0.1);   % 100 ms window
```

### Overlap (`noverlap`)
- How much each window overlaps with the next (in samples)
- More overlap = smoother, more detailed spectrogram (but slower)
- Typical: 50–75% of window length

```matlab
noverlap = round(window * 0.75);   % 75% overlap
```

### FFT Size (`nfft`)
- Controls frequency resolution
- Must be >= window length; powers of 2 are fastest (e.g., 512, 1024, 2048)

```matlab
nfft = 1024;
```

---

## Step 4: Generate the Spectrogram

```matlab
figure;
spectrogram(x, window, noverlap, nfft, Fs, 'yaxis');
colormap('jet');        % color scheme
colorbar;               % show amplitude scale
title('Spectrogram');
xlabel('Time (s)');
ylabel('Frequency (Hz)');
```

> **Note:** The `'yaxis'` flag puts frequency on the y-axis (the standard orientation).

---

## Step 5: Adjust the Color Scale

By default the color scale can look washed out. Limit it to highlight the signal:

```matlab
clim([-100 -20]);   % adjust these values for your signal (in dB)
```

- `-100` is the minimum (noise floor)
- `-20` is the maximum (loud signal)
- Adjust until your signal stands out clearly

---

## Step 6: Limit the Frequency Axis (Optional)

If your signal only lives in a certain frequency band, zoom in:

```matlab
ylim([0 5000]);   % show only 0–5 kHz
```

---

## Full Example Script

```matlab
% ---- Load audio ----
[x, Fs] = audioread('your_file.wav');
x = x(:, 1);                          % use channel 1 if stereo

% ---- Parameters ----
window   = round(Fs * 0.1);           % 100 ms window
noverlap = round(window * 0.75);      % 75% overlap
nfft     = 1024;                      % FFT size

% ---- Plot ----
figure;
spectrogram(x, window, noverlap, nfft, Fs, 'yaxis');
colormap('jet');
colorbar;
clim([-100 -20]);                      % adjust to your signal
title('Spectrogram');
xlabel('Time (s)');
ylabel('Frequency (Hz)');
```

---

## Common Issues and Fixes

| Problem | Likely cause | Fix |
|---------|-------------|-----|
| Spectrogram looks all one color | Color scale is off | Adjust `clim` values |
| Can't see fine frequency detail | Window too short | Increase `window` length |
| Signal smeared in time | Window too long | Decrease `window` length |
| Script runs slowly | Overlap too high or nfft too large | Reduce `noverlap` or use a power-of-2 `nfft` |
| `audioread` error | Wrong file path | Use full path or `cd` to the file's folder |

---

## Further Reading

- MATLAB docs: `help spectrogram` in the Command Window
- Bioacoustics: Bregman, A.S. *Auditory Scene Analysis* (1990)
- Signal processing basics: [The Scientist and Engineer's Guide to DSP](http://www.dspguide.com/) (free online)
