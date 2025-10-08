%%

clc 
clear all 
close all


%% Test whether there is a cpod device conntected to machine 

clear device

device_found = 0;
ports = serialportlist("available");

for p = 1:length(ports)
    device = serialport(ports(p),115200,"Timeout",1);
    %In order to identify an XID device, you need to send it "_c1", to
    %which it will respond with "_xid" followed by a protocol value. 0 is
    %"XID", and we will not be covering other protocols.
    device.flush()
    write(device,"_c1","char")
    query_return = read(device,5,"char");
    if length(query_return) > 0 && query_return == "_xid0"
        device_found = 1;
        break
    end
end

if device_found == 0
    disp("No XID device found. Exiting.")
    return
end

disp("Raising all output lines for 1 second.")

%By default the pulse duration is set to 0, which is "indefinite".rgbbrgbb
%You can either set the necessary pulse duration, or simply lower the lines
%manually when desired.

setPulseDuration(device, 50)

%mh followed by two bytes of a bitmask is how you raise/lower output lines.
%Not every XID device supports 16 bits of output, but you need to provide
%both bytes every time.

write(device,sprintf("mh%c%c", 250, 0), "char")


function byte = getByte(val, index)
    byte = bitand(bitshift(val,-8*(index-1)), 255);
end

function setPulseDuration(device, duration)

%mp sets the pulse duration on the XID device. The duration is a four byte
%little-endian integer.
    write(device, sprintf("mp%c%c%c%c", getByte(duration,1),...
        getByte(duration,2), getByte(duration,3),...
        getByte(duration,4)), "char")
end

%% 

%----------------------------------------------------------------------
%                       Setup
%----------------------------------------------------------------------

Screen('Preference', 'SkipSyncTests', 1)

out.ExpStartTime = datetime;

% Setup PTB with some default values
PsychDefaultSetup(2);

% random number generator, useful 
rng('shuffle')

screenNumber = max(Screen('Screens')); %select the screen number based on the highest value, low is always the native display

% Define black, white and grey
white = WhiteIndex(screenNumber);
grey = white / 2;
black = BlackIndex(screenNumber);

% Open the screen
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey, [], 32, 2);

% Flip to clear
Screen('Flip', window);  % i understand this to be a timesync command? 

% Query the frame duration
ifi = Screen('GetFlipInterval', window);

% Set the text size
Screen('TextSize', window, 60);

% Get the centre coordinate of the window
[xCenter, yCenter] = RectCenter(windowRect);

% Here we set the size of the arms of our fixation cross
fixCrossDimPix = 40;

% Now we set the coordinates (these are all relative to zero we will let
% the drawing routine center the cross in the center of our monitor for us)
xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
allCoords = [xCoords; yCoords];

% Set the line width for our fixation cross
lineWidthPix = 4;

% Set the blend funciton for the screen
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% Set maximum priority level
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

%----------------------------------------------------------------------
%                       Timing Information
%----------------------------------------------------------------------

presTimeSecs = 1;
presTimeFrames = round(presTimeSecs / ifi);

% Interstimulus interval time in seconds and frames
isiTimeSecs = 1;
isiTimeFrames = round(isiTimeSecs / ifi);

% Numer of frames to wait before re-drawing
waitframes = 1;


%----------------------------------------------------------------------
%                       Keyboard information
%----------------------------------------------------------------------

% Define the keyboard keys that are listened for. We will be using the left
% and right arrow keys as response keys for the task and the escape key as
% a exit/reset key

escapeKey = KbName('ESCAPE');
greenKey = KbName('G');
redKey = KbName('R');
blueKey = KbName('B');


%----------------------------------------------------------------------
%                     Colors in words and RGB
%----------------------------------------------------------------------

%% Creating Trial Stimuli Matrix

% Controls number of trials per condition. If 8 words, then number of trials = 8 word conditions * 8 trials per condition * 2 cue types = 128 trials in total. 
% each trial = 4 seconds 
% total experiment time estimate = 128*4 = 8 and a half minutes

trialsPerCondition = 8;

cues = [1,2];

numCues = length(cues);

% list of words and all of the corresponding colours
wordList = {'Red', 'Green', 'Blue', 'Brown', 'Pink', 'White', 'Purple', 'Yellow', 'XXXX'};

rgbColors = [1 0 0; 0 1 0; 0 0 1; 0.4196 0.2314, 0.0549; 1 0.4 0.6; 1 1 1; 0.4627 0.1412 0.6196; 1 1 0];

numColors = length(wordList);

% Make the matrix which will determine our condition combinations

congruentConditions = [1:numColors; 1:numColors];

incongruentConditions = [];

for i = 1:numColors

    nonCongruent = setdiff(1:numColors, i);
    incongruentConditions = [incongruentConditions, [repmat(i, 1, numColors-1); nonCongruent]];
    
end

% Calculate the number of congruent and incongruent trials
numTrials = numColors * trialsPerCondition * numCues;

condMatrixCongruent = repmat(congruentConditions, 1, trialsPerCondition);

% Randomly sample X number of columns from incongruentConditions

selectedIncongruent = incongruentConditions(:, randi(size(incongruentConditions, 2), 1, size(condMatrixCongruent, 2)));

% Combine the selected congruent and incongruent conditions
condMatrixBase = [condMatrixCongruent, selectedIncongruent];

condMatrixBase(3,:) = repmat(cues, 1, ceil(numTrials / numCues)); % Ensure even distribution of cue types
condMatrixBase(3,:) = condMatrixBase(3, 1:numTrials); % Trim to match the exact number of trials

% Randomise the conditions
shuffler = Shuffle(1:numTrials);

condMatrixShuffled = condMatrixBase(:, shuffler);

%----------------------------------------------------------------------
%                     Biasing the conditions
%----------------------------------------------------------------------

% I want to create a number of trials where 80% of trials are congruent and 20% % are incongruent. I will do this by creating a matrix of 80% congruent
% conditions and 20% incongruent conditions. I will then randomise the
% conditions and then append the two matrices together.

condMatrixSkewed = [];
trialsCongruent_skewed = round((128 / 100) * 50); % 80% congruent trials
trialsIncongruent_skewed = round((128 / 100) * 50); % 20% incongruent trials

condMatrixCongruent_skewed = repmat(congruentConditions, 1, ceil(102 / size(congruentConditions, 2)));
condMatrixCongruent_skewed = condMatrixCongruent_skewed(:, 1:102); % Trim to exactly 102 trials

condMatrixIncongruent_skewed = repmat(incongruentConditions, 1, ceil(trialsIncongruent_skewed / size(incongruentConditions, 2)));
condMatrixIncongruent_skewed = condMatrixIncongruent_skewed(:, 1:trialsIncongruent_skewed); % Trim to exactly 102 trials


% Combine the selected congruent and incongruent conditions
condMatrixSkewed = [condMatrixCongruent_skewed, condMatrixIncongruent_skewed];

condMatrixSkewed(3,:) = repmat(cues, 1, ceil(numTrials / numCues)); % Ensure even distribution of cue types
condMatrixSkewed(3,:) = condMatrixBase(3, 1:numTrials);
% Randomise the conditions
shuffler = Shuffle(1:numTrials);

condMatrixSkewedShuffled = condMatrixSkewed(:, shuffler);

%----------------------------------------------------------------------
%                     Make a response matrix
%----------------------------------------------------------------------

% This is a four row matrix the first row will record the word we present,
% the second row the color the word it written in, the third row the key
% they respond with and the final row the time they took to make there response.

out.respMat = nan(5, numTrials);


%----------------------------------------------------------------------
%                       Experimental loop
%----------------------------------------------------------------------

%begin recording
recObj = audiorecorder(44100,16,2);
record(recObj); 
disp("Recording Started")

% Animation loop: we loop for the total number of trials
for trial = 1:numTrials
    
    if trial == 1
        
        
        DrawFormattedText(window, 'You are 1/2 through the task. Please take a break. \n\n \n\n When you are ready, press any button to begin',...
            'center', 'center', black);
        
            Screen('Flip', window);
        
            KbStrokeWait;
    end 


    if trial == numTrials/2
        
        
        DrawFormattedText(window, 'You are 3/4 through the task. Please take a break. \n\n \n\n When you are ready, press any button to continue',...
            'center', 'center', black);
        
            Screen('Flip', window);
        
            KbStrokeWait;
    end 

    % Word and color number
    wordNum = condMatrixShuffled(1, trial);
    colorNum = condMatrixShuffled(2, trial);

    % The color word and the color it is drawn in
    theWord = wordList(wordNum);
    theColor = rgbColors(colorNum, :);

    % Cue to determine whether a response has been made
    respToBeMade = true;

    % Phase 1: Fixation Cross
    Screen('DrawLines', window, allCoords, lineWidthPix, white, [xCenter yCenter], 2);
    Screen('Flip', window);
    write(device,sprintf("mh%c%c", 66, 0), "char")
    WaitSecs(1);  % Display fixation cross for 1 second

    % Phase 2: Cue
    % Define the path to the icons folder
    iconsFolder = fullfile(fileparts(mfilename('fullpath')), '..', 'icons');

    % List all files in the icons folder
    iconFiles = dir(fullfile(iconsFolder, '*.png'));

    % Check if there are at least two icons
    if length(iconFiles) < 2
        error('Not enough icon files in the icons folder.');
    end

    % Assign the cue condition from the predefined sequence
    cueCondition = condMatrixShuffled(3, trial);
    iconFile = iconFiles(cueCondition).name;

    % Load the selected icon
    theImageLocation = fullfile(iconsFolder, iconFile);
    [theImage, ~, alpha] = imread(theImageLocation);

    % Add alpha channel if it exists
    if ~isempty(alpha)
        theImage(:,:,4) = alpha;
    end

    % Resize the image to a standard size (e.g., 200x200 pixels)
    standardSize = [200, 200];
    theImage = imresize(theImage, standardSize);

    % Make the image into a texture
    imageTexture = Screen('MakeTexture', window, theImage);

    % Draw the image to the screen
    Screen('DrawTexture', window, imageTexture, [], [], 0);
    Screen('Flip', window);
    write(device,sprintf("mh%c%c", 255, 0), "char")
    WaitSecs(1);  % Display cue for 1 second

    % Phase 3: Stimulus Presentation
    DrawFormattedText(window, char(theWord), 'center', 'center', theColor);
    Screen('Flip', window);
    write(device,sprintf("mh%c%c", 255, 0), "char")
    WaitSecs(1);  % Display stimulus for 1 second

    % Phase 4: Response
    circleRadius = fixCrossDimPix / 2;
    Screen('FillOval', window, white, [xCenter - circleRadius, yCenter - circleRadius, xCenter + circleRadius, yCenter + circleRadius]);
    vbl = Screen('Flip', window);
    write(device,sprintf("mh%c%c", 255, 0), "char")

    startTime = GetSecs;
    response = 0;  % Default response is no input
    while GetSecs - startTime < 1  % Loop for 1 second
        [keyIsDown, secs, keyCode] = KbCheck;
        if keyCode(escapeKey)
            ShowCursor;
            sca;
            return;
        elseif keyCode(greenKey)
            response = 2;
        elseif keyCode(blueKey)
            response = 3;
        elseif keyCode(redKey)
            response = 1;
        end

        % Redraw "RESPOND" text during each iteration of the loop
        Screen('FillOval', window, white, [xCenter - circleRadius, yCenter - circleRadius, xCenter + circleRadius, yCenter + circleRadius]);
        vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
    end

    % Send signal after 1 second
    write(device, sprintf("mh%c%c", 99, 0), "char");

    rt = GetSecs - startTime;  % Calculate reaction time
    out.respMat(1, trial) = wordNum;
    out.respMat(2, trial) = colorNum;
    out.respMat(3, trial) = cueCondition;
    out.respMat(4, trial) = response;
    out.respMat(5, trial) = rt;
end

DrawFormattedText(window, 'Experiment Finished \n\n Press Any Key To Exit', 'center', 'center', black);
Screen('Flip', window);
write(device,sprintf("mh%c%c", 254, 0), "char")
KbStrokeWait;

stop(recObj)
disp("Recording Ended")


out.audio_data = getaudiodata(recObj); 


% Save the "out" structure as a .mat file with the name "Stroop" + today's date
dateString = datestr(now, 'dd-mm-yyyy_HH-MM-SS');
saveFileName = ['Stroop_' dateString '.mat'];

% Define the output folder path
outputFolder = fullfile(fileparts(mfilename('fullpath')), 'output', datestr(now, 'dd-mm-yyyy'));

% Create the folder if it doesn't exist
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Define the full path to the save file
saveFilePath = fullfile(outputFolder, saveFileName);

% Save the "out" structure as a .mat file
save(saveFilePath, 'out');



sca;
clc;

%% Draft
