# Stroop Task Experiment

A configurable Stroop task implementation in MATLAB using Psychtoolbox, designed for cognitive research with TTL pulse support for EEG/sEEG recording.

## Overview

This Stroop task presents participants with color words (Red, Green, Blue, etc.) displayed in congruent, incongruent, or neutral colors. The experiment measures electrophysiological response across different conflict conditions to study cognitive control and interference. Reaction time can also be infered through the audio recording

## Requirements

### Software
- MATLAB (R2019b or later recommended)
- [Psychtoolbox-3](http://psychtoolbox.org/)
- Image Processing Toolbox (for icon resizing)

### Hardware
- Computer with display
- Audio recording capability
- Optional: XID device for TTL pulses (experiment runs without it)

## Project Structure

```
Stroop Task/
├── README.md               # This file
├── .gitignore             # Git ignore rules (excludes output/)
├── scripts/
│   ├── stroopTask.m       # Main experiment function
│   ├── instructions.m     # Instructions and practice trials
│   └── archive/          # Legacy/backup scripts
├── icons/
│   ├── colour_icon.png   # Cue icon 1
│   └── text_icon.png     # Cue icon 2
└── output/               # Experiment data (auto-generated)
    └── YYYY-MM-DD/       # Date-specific folders
        ├── low/          # Low conflict data
        ├── equal/        # Equal conflict data
        └── high/         # High conflict data
```

## Usage

### Trial Proportions

| Condition | Congruent | Incongruent | Neutral |
|-----------|-----------|-------------|---------|
| Low (1)   | 80%       | 0%          | 20%     |
| Equal (2) | 50%       | 30%         | 20%     |
| High (3)  | 30%       | 50%         | 20%     |

### Basic Usage

```matlab
% Add project to MATLAB path
addpath(genpath('path/to/Stroop Task'))

% Run different conflict conditions
stroopTask(1);     % Low conflict (80% congruent)
stroopTask(2);   % Equal conflict (50% congruent)  
stroopTask(3);    % High conflict (30% congruent)

```

### Experiment Flow

Each trial consists of:
1. **Fixation cross** (1s) - TTL code: 66
2. **Cue icon** (1s) - TTL code: 99
3. **Stimulus word** (2s) - TTL code: 255
4. **Response collection** during stimulus presentation
5. **End marker** - TTL code: 254

### Response Keys

- **Escape**: Exit experiment early

## Output Data

### File Naming
```
Stroop_t<TYPE>_<LABEL>_<TIMESTAMP>.mat
```
Example: `Stroop_t1_low_08-10-2025_14-32-10.mat`

### Data Structure

```matlab
out = struct(
    'stroop_type',   1,                    % Condition type (1,2,3)
    'label',        'Low conflict',        % Human-readable label
    'label_short',  'low',                % Short label for files
    'pct',          [80, 0, 20],          % [congruent, incongruent, neutral] %
    'counts',       struct(...),          % Actual trial counts
    'respMat',      [3 x nTrials],        % [wordIdx; colorIdx; cue]
    'audio_data',   [...],                % Recorded audio
    'ExpStartTime', datetime(...)         % Experiment timestamp
);
```

### Response Matrix (`out.respMat`)

- **Row 1**: Word index (1-8 for colors, 9 for "XXXX")
- **Row 2**: Color index (1-8 for RGB colors)
- **Row 3**: Cue condition (1 or 2, corresponding to icon files)

## TTL Pulse Codes

| Event | Code | Description |
|-------|------|-------------|
| Fixation onset | 66 | Cross appears |
| Cue onset | 255 | Icon appears |
| Stimulus onset | 255 | Word appears |
| Response window end | 99 | Trial complete |
| Block end | 254 | Experiment finished |

## Colors and Words

**Words**: Red, Green, Blue, Brown, Pink, White, Purple, Yellow, XXXX (neutral)
**Colors**: Corresponding RGB values for the first 8 words

## Contact

**Author**: Jakub Kowalczyk  
**Institution**: Newcastle University  
**Email**: j.kowalczyk2@newcastle.ac.uk
**Last Updated**: October 2025