# NC4Touch Audio Analysis Pipeline

MATLAB pipeline for calibrated sound pressure level (SPL) analysis of acoustic events recorded during NC4Touch rodent behavioural sessions.

---

## Overview

This pipeline:
1. Loads raw audio recordings and NC4Touch event files (`.json`)
2. Trims audio to session start using event timestamps
3. Applies a bandpass filter (200–90,000 Hz)
4. Applies microphone calibration to convert raw audio to Pascals
5. Extracts per-event audio windows across trials
6. Computes mean SPL (dB) per event
7. Applies baseline correction
8. Compares conditions (e.g. box-open vs box-closed) and generates a grouped bar plot

---

## Hardware

- **Microphone:** Pettersson M500-384 ultrasonic microphone
- **Chamber:** Custom sound-attenuated NC4Touch chamber (MDF + soundproofing foam)
- **Sample rate:** 192,000 Hz

---

## Repository Structure

```
nc4touch-audio/
├── audio_analysis/
│   ├── master_analysis.m               # Main script — run this
│   ├── calibration_ui.m                # Interactive UI for labeling calibration tones
│   └── calibrate_from_manual_labels.m  # Computes calibration gain from labeled segments
├── .gitignore
└── README.md
```

---

## Getting Started

### Requirements
- MATLAB R2021a or later
- Signal Processing Toolbox (for `designfilt`, `filtfilt`)
- Audio Toolbox (for `audioread`, `audiowrite`)

### Data files (not included in repo)
The following files are required but excluded from version control due to size:

| File | Description |
|---|---|
| `*.wav` | Raw audio recordings |
| `*.mat` | Calibration parameters and saved results |
| `*.json` | NC4Touch event files |

Contact the NC4 lab for access to data files.

---

## Calibration Procedure

Calibration converts raw normalized audio ([-1, 1]) into calibrated Pascals using a linear gain `G`.

1. Record a calibration tone using a standard acoustic calibrator (94/104/114 dB SPL) placed directly on the Pettersson M500-384
2. Run `calibration_ui.m` to manually label tone segments — click 4 start/end pairs per tone level
3. Run `calibrate_from_manual_labels.m` to compute and save `calibrationGain_G`
4. Verify calibration with sanity check (expected: ~94 dB from a 94 dB tone segment)

The calibration formula is:
```
dB_SPL = 10 * log10(mean((audio * G).^2) / (20e-6)^2)
```

---

## Running the Analysis

1. Open `master_analysis.m`
2. Edit the **CONFIG** section at the top:
   - Set `audioFile`, `audioStart`, and `eventFile` for each condition
   - Set `calibPath` to your `calibration_params.mat`
   - Set `baseDir` to your analysis output directory
   - Set `baselineMean` from your baseline recording
3. Run the script — results and plots are saved automatically

### Adding a new condition
Add an entry to the `conditions` struct in the CONFIG section:
```matlab
conditions(3).name       = 'new_condition';
conditions(3).audioFile  = '/path/to/audio.wav';
conditions(3).audioStart = datetime('YYYY-MM-DD HH:mm:ss.SSS', 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
conditions(3).eventFile  = '/path/to/events.json';
```

---

## Baseline

Baseline SPL is computed from a separate recording of the empty chamber under the same hardware conditions. The baseline mean is subtracted from all event SPL values to yield relative dB.

**Known limitation:** The chamber electronics (Raspberry Pi and associated hardware) contribute a noise floor of approximately 69 dB SPL, which is higher than the 30–40 dB expected for a fully isolated chamber. Fan-on vs fan-off recordings confirmed the cooling fan contributes less than 1 dB to this noise floor. This elevated baseline is an acknowledged limitation of the current setup.

---

## Output

The pipeline produces:
- Per-condition `.mat` files with event-level mean, median, std, and corrected dB SPL
- A grouped bar plot comparing relative dB SPL across conditions with error bars and paired t-test annotation

---

## Credits

- **Calibration code** (`calibration_ui.m`, `calibrate_from_manual_labels.m`): Originally written by Adam Lester (Postdoctoral Researcher), with one modification by Amy Wong: in `calibration_ui.m`, `dB_vals` computation was corrected from `20 * log10(segRMS)` to `20 * log10(segRMS / 20e-6)` to include the reference pressure denominator, which was causing calibration gain to be inflated by several orders of magnitude.
- **Analysis pipeline** (`master_analysis.m`): Amy Wong

---