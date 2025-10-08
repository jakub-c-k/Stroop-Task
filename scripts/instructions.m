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

% random number generator
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

% We are going to use three colors for this demo. Red, Green and blue.
wordList = {'Red', 'Green', 'Blue'};
rgbColors = [1 0 0; 0 1 0; 0 0 1];

% Make the matrix which will determine our condition combinations
condMatrixBase = [sort(repmat([1 2 3], 1, 3)); repmat([1 2 3], 1, 3)];

% Number of trials per condition. We set this to 2 for this demo, to give
% us a total of 18 trials.
trialsPerCondition = 1;

% Duplicate the condition matrix to get the full number of trials
condMatrix = repmat(condMatrixBase, 1, trialsPerCondition);

% Get the size of the matrix
[~, numTrials] = size(condMatrix);

% Randomise the conditions
shuffler = Shuffle(1:numTrials);
condMatrixShuffled = condMatrix(:, shuffler);


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
recObj = audiorecorder; 
record(recObj); 
disp("Recording Start")

% Animation loop: we loop for the total number of trials
for trial = 1:numTrials

    % Word and color number
    wordNum = condMatrixShuffled(1, trial);
    colorNum = condMatrixShuffled(2, trial);

    % The color word and the color it is drawn in
    theWord = wordList(wordNum);
    theColor = rgbColors(colorNum, :);

    % Cue to determine whether a response has been made
    respToBeMade = true;

    % If this is the first trial we present a start screen and wait for a
    % key-press
    if trial == 1
        
        write(device,sprintf("mh%c%c", 33, 0), "char")

        DrawFormattedText(window, 'Practice Trials \n\n \n\n Press any button to continue',...
            'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;

        DrawFormattedText(window, 'You will be presented with a cue (a colour wheel or a book) \n\n \n\n Press any button to continue',...
            'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;

        DrawFormattedText(window, 'Following this, you will be presented with the target word' ,...
            'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;


        DrawFormattedText(window, 'Respond to either the text (book) or colour (colour wheel) of the target' ,...
            'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;

        DrawFormattedText(window, 'Here are 2 practice examples...' ,...
            'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;
        
        % Insert cue here

        % Define the path to the icons folder
        iconsFolder = fullfile(fileparts(mfilename('fullpath')), '..', 'icons');

        % List all files in the icons folder
        iconFiles = dir(fullfile(iconsFolder, '*.png'));

        % Randomly choose between two icons
        cueCondition = 1;

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
        KbStrokeWait;
        
        % Example 1: "Red" in green color
        exampleWord = 'Red';
        exampleColor = [0 1 0];  % Green
        DrawFormattedText(window, exampleWord, 'center', 'center', exampleColor);
        Screen('Flip', window);
        KbStrokeWait

        DrawFormattedText(window, 'Here the correct answer would have been "GREEN"' ,...
            'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;

        cueCondition = 2;
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
        KbStrokeWait;

        % Example 2: "Blue" in red color
        exampleWord = 'Blue';
        exampleColor = [1 0 0];  % Red
        DrawFormattedText(window, exampleWord, 'center', 'center', exampleColor);
        Screen('Flip', window);
        WaitSecs(1);

        DrawFormattedText(window, 'Here the correct answer would have been "BLUE"' ,...
            'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;
        
          DrawFormattedText(window, 'The next few trials will be practice trials. \n\n \n\n Press any button once you are ready to start...',...
            'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait;

    end

    % Phase 1: Fixation Cross

    
    Screen('DrawLines', window, allCoords, lineWidthPix, white, [xCenter yCenter], 2);

    Screen('Flip', window);

    write(device,sprintf("mh%c%c", 33, 0), "char")

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

    % Randomly choose between two icons
    cueCondition = randi([1, 2]);
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
    write(device,sprintf("mh%c%c", 33, 0), "char")

    WaitSecs(1);  % Display cue for 1 second

    % Phase 3: Stimulus Presentation
    DrawFormattedText(window, char(theWord), 'center', 'center', theColor);
    Screen('Flip', window);
    write(device,sprintf("mh%c%c", 255, 0), "char")


    WaitSecs(1);  % Display stimulus for 1 second

    % Phase 4: Response
    % Draw a small white circle at the center of the screen
    circleRadius = fixCrossDimPix / 2;  % Set the radius to half the size of the fixation cross
    Screen('FillOval', window, white, [xCenter - circleRadius, yCenter - circleRadius, xCenter + circleRadius, yCenter + circleRadius]);
    vbl = Screen('Flip', window);
    write(device,sprintf("mh%c%c", 33, 0), "char");

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

        % Redraw response circle text during each iteration of the loop
        Screen('FillOval', window, white, [xCenter - circleRadius, yCenter - circleRadius, xCenter + circleRadius, yCenter + circleRadius]);
        vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
    end

    % Send signal after 1 second
    write(device, sprintf("mh%c%c", 33, 0), "char");

    rt = GetSecs - startTime;  % Calculate reaction time
    out.respMat(1, trial) = wordNum;
    out.respMat(2, trial) = colorNum;
    out.respMat(3, trial) = cueCondition;
    out.respMat(4, trial) = response;
    out.respMat(5, trial) = rt;
end

DrawFormattedText(window, 'Practice trial finished \n\n Press Any Key ', 'center', 'center', black);
Screen('Flip', window);
write(device,sprintf("mh%c%c", 33, 0), "char")
KbStrokeWait;

stop(recObj)
disp("Recording End")

% Clear and Close

sca;
clc;

stroopTask(1)