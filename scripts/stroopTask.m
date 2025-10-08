% stroopTask.m

% Run a Stroop task with configurable conflict proportions.

% Usage:
%   out = stroopTask(stroop_type)
%       stroop_type: 1 = low conflict (80% cong), 2 = equal conflict (50% cong), 3 = high conflict (30% cong)

% Returns:
% 
% out: struct with responses, audio, and metadata
% Output codes (TTL pulse values sent via write(device, ...))
%
% The codes for the TTL pulses are:
% - 66: Fixation cross onset
% - 255: Cue icon onset, stimulus word onset, response window onset
% - 99: End of response window
% - 254: End of experiment block
%
% Author: Jakub Kowalczyk 
% Edited: 06.10.2025

function out = stroopTask(stroop_type)

% Validate input

if nargin < 1 || ~ismember(stroop_type, [1, 2, 3])
    error('Invalid stroop_type. Must be 1 (low conflict), 2 (equal conflict), or 3 (high conflict).');
end

% Map requested conflict proportions [congruent, incongruent, neutral]

switch stroop_type
    case 1, pct = [60, 20, 20]; label = 'Low conflict';  labelShort = 'low';
    case 2, pct = [30, 50, 20]; label = 'Equal conflict'; labelShort = 'equal';
    case 3, pct = [10, 70, 20]; label = 'High conflict'; labelShort = 'high';
end

% -------------------- TTL Pulse Setup -------------------- %

% Optional XID device setup - used to send TTL pulses to Nautilus sEEG system. Used as markers for stimulus-locking neural activity. 
% Ignore if not applicable

device = [];
device_found = 0;
ports = serialportlist("available");

for p = 1:length(ports)
    try
        device = serialport(ports(p),115200,"Timeout",1);
        device.flush();
        write(device,"_c1","char");
        query_return = read(device,5,"char");
        if length(query_return) > 0 && strcmp(query_return, "_xid0")
            device_found = 1;
            break
        end
    catch
        % Ignore errors and continue searching
        device = [];
    end
end

if device_found == 1
    setPulseDuration(device, 50); % 50 ms pulses
    write(device,sprintf("mh%c%c", 250, 0), "char"); % set all high briefly
else
    disp("No XID device found. TTL pulses will be skipped.");
end


function byte = getByte(val, index)
    byte = bitand(bitshift(val,-8*(index-1)), 255);
end

function setPulseDuration(dev, duration)
    write(dev, sprintf("mp%c%c%c%c", getByte(duration,1), getByte(duration,2), getByte(duration,3), getByte(duration,4)), "char")
end

% -------------------- PTB Setup --------------------

Screen('Preference', 'SkipSyncTests', 1);
out.ExpStartTime = datetime; 

PsychDefaultSetup(2);
rng('shuffle'); % set random seed for shuffling
screenNumber = max(Screen('Screens')); % use second screen if possible

white = WhiteIndex(screenNumber); grey = white/2; black = BlackIndex(screenNumber); % define colours 

[window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey, [], 32, 2);
Screen('Flip', window);
ifi = Screen('GetFlipInterval', window);
Screen('TextSize', window, 60);
[xCenter, yCenter] = RectCenter(windowRect);

% Fixation cross parameters

fixCrossDimPix = 40;
xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
allCoords = [xCoords; yCoords];
lineWidthPix = 4;
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
topPriorityLevel = MaxPriority(window); Priority(topPriorityLevel);

% Timing

presTimeSecs = 1;
isiTimeSecs = 1; 
waitframes = 1;

% Keys

escapeKey = KbName('ESCAPE');


% -------------------- Build Conditions --------------------

% Choose a total trial count divisible by 10 and 2 so our percentages and cues are exact.

totalTrials = 200; % Adjust as needed, but keep divisible by 10 and 2 - 200 = 10 mins (200*3s / 60) 

cues = [1, 2]; numCues = numel(cues);

wordList = {'Red','Green','Blue','Brown','Pink','White','Purple','Yellow','XXXX'};

rgbColors = [
    1 0 0;
    0 1 0;
    0 0 1;
    0.4196 0.2314 0.0549;
    1 0.4 0.6;
    1 1 1;
    0.4627 0.1412 0.6196;
    1 1 0
];

numColors = 8; % exclude neutral word

% Pools (word index; color index)
congruent = [1:numColors; 1:numColors];

incongruent = [];
for i = 1:numColors
    other = setdiff(1:numColors, i);
    incongruent = [incongruent, [repmat(i,1,numel(other)); other]]; %#ok<AGROW>
end

neutral = [repmat(numColors+1,1,numColors); 1:numColors];

% Counts from percentages
nCong   = round(totalTrials * pct(1) / 100);
nIncong = round(totalTrials * pct(2) / 100);
nNeut   = totalTrials - nCong - nIncong; % absorb rounding

% Ensure enough columns then trim
ensureCols = @(M,N) repmat(M,1,ceil(N/size(M,2)));
cPool = ensureCols(congruent,   nCong);
iPool = ensureCols(incongruent, nIncong);
nPool = ensureCols(neutral,     nNeut);

selCong    = cPool(:,1:nCong);
selIncong  = iPool(:,1:nIncong);
selNeutral = nPool(:,1:nNeut);

% Combine and add cues evenly
condMatrix = [selCong, selIncong, selNeutral]; % 2 x totalTrials
cueSeq = repmat(cues, 1, ceil(totalTrials/numCues));
condMatrix(3,:) = cueSeq(1:totalTrials);
shuffler = randperm(totalTrials);
condMatrixShuffled = condMatrix(:, shuffler);

% Response matrix: [wordIdx; colorIdx; cue; response; rt]
numTrials = totalTrials;
out.respMat = nan(3, numTrials);
% Also store planned counts for traceability
out.counts = struct('congruent', nCong, 'incongruent', nIncong, 'neutral', nNeut);



% -------------------- Recording --------------------

% Set up audio recording used for response locking of EEG activity.
recObj = audiorecorder(44100,16,2);
record(recObj);
disp("Recording Started")

% -------------------- Trial loop --------------------

for trial = 1:numTrials
    if trial == 1

        DrawFormattedText(window, 'When you are ready, press any button to begin', 'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;

    elseif trial == (numTrials/2)
        DrawFormattedText(window, 'You are halfway through the task. Take a short break.\n\n Press any key to continue.', 'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;
    end

    % Current condition

    wordNum  = condMatrixShuffled(1, trial);
    colorNum = condMatrixShuffled(2, trial);
    cueCondition = condMatrixShuffled(3, trial);
    theWord  = wordList{wordNum};
    theColor = rgbColors(colorNum, :);

    % Phase 1: Fixation
    Screen('DrawLines', window, allCoords, lineWidthPix, white, [xCenter yCenter], 2);
    Screen('Flip', window);
    write(device,sprintf("mh%c%c", 66, 0), "char");
    WaitSecs(1); 
    
    % Phase 2: Cue (icon)
    iconsFolder = fullfile(fileparts(mfilename('fullpath')), '..', 'icons');
    iconFiles = dir(fullfile(iconsFolder, '*.png'));

    if numel(iconFiles) < 2
        error('Not enough icon files in the icons folder.');
    end

    iconFile = iconFiles(cueCondition).name;
    [theImage, ~, alpha] = imread(fullfile(iconsFolder, iconFile));
    
    if ~isempty(alpha), theImage(:,:,4) = alpha; end
    
    theImage = imresize(theImage, [200, 200]);
    imageTexture = Screen('MakeTexture', window, theImage);
    
    Screen('DrawTexture', window, imageTexture, [], [], 0);
    Screen('Flip', window);
    write(device,sprintf("mh%c%c", 99, 0), "char");
    WaitSecs(1); 

    % Phase 3: Stimulus
    DrawFormattedText(window, theWord, 'center', 'center', theColor);
    Screen('Flip', window);
    write(device,sprintf("mh%c%c", 255, 0), "char");
    WaitSecs(2); % stimulus presentation time
    write(device,sprintf("mh%c%c", 255, 0), "char"); % response window end

    % Save response

    out.respMat(1, trial) = wordNum;
    out.respMat(2, trial) = colorNum;
    out.respMat(3, trial) = cueCondition;

end

% -------------------- End Screen -------------------- %

DrawFormattedText(window, sprintf('block finished.\n\nPress any key to exit.'), 'center', 'center', black);
Screen('Flip', window);
write(device,sprintf("mh%c%c", 254, 0), "char");
KbStrokeWait;

% -------------------- Stop Recording  -------------------- %

stop(recObj); disp("Recording Ended");
out.audio_data = getaudiodata(recObj);


% -------------------- Save Data -------------------- %

dateString = datestr(now, 'dd-mm-yyyy_HH-MM-SS');
% Save under date/type subfolder and include type+label in filename

projectFolder = fileparts(fileparts(mfilename('fullpath'))); % go up from 'scripts' to project ('Stroop Task') folder
outputFolder = fullfile(projectFolder, 'output', datestr(now, 'dd-mm-yyyy'), labelShort);
% Ensure stroop_type is represented as text (works if it's numeric, char, or string)
saveFileName = sprintf('Stroop_%s_%s_%s.mat', labelShort, dateString);

if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end
saveFilePath = fullfile(outputFolder, saveFileName);
out.stroop_type = stroop_type; out.label = label; out.label_short = labelShort; out.pct = pct;
save(saveFilePath, 'out');

sca; clc;

end

% -------------------- FIN -------------------- %