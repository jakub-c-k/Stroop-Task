

recObj = audiorecorder(44100,16,2);

%% 

recDuration = 5;
disp("Begin")

recordblocking(recObj, recDuration);

disp("End")


%%
play(recObj)

%%
stop(recObj)
disp("End")

%%

%play(recObj)
pause(recObj)

%% 

y =  getaudiodata(recObj); 
plot(y);

%% 

info = audiodevinfo