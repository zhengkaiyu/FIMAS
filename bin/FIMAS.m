function FIMAS
% FIMAS Main executable of the FIMAS software
%   Initialises environment for programme and start the main GUI
%% function complete
% ---------------------------------------------------
% clear command window
clc;
% stop for debugging if error
dbstop if error;
% But don't bother with warnings
warning off all;
% ---------------------------------------------------
% get current file path
funcpath=mfilename('fullpath');
% move to base directory as we know \bin\FIMAS.m
cd(fileparts(funcpath));
cd('../');
% find all subdirectory
path=cat(2,pwd,filesep);
% add all subdirectory for libraries
addpath(genpath(path));
% ---------------------------------------------------
% add bio-format reader into java path for file import
status = bfCheckJavaPath(1);
assert(status, ['Missing Bio-Formats library. Either add loci_tools.jar '...
    'to the static Java path or add it to the Matlab path.']);
% ---------------------------------------------------
% version related initialisation for parallel computing
[ ver, date ] = version;
release_yr = str2double(datestr(date,'YYYY'));
switch release_yr
    case {2018,2019,2020}
        feature('accel','on');
    otherwise
        errordlg(sprintf('Incompatible MATLAB Version.\nCurrent Version %s\nRequire >R2018b',ver),'Version Error','modal');
end
% ---------------------------------------------------
% profile -memory on;
% ---------------------------------------------------
% open main gui interface
MAIN_GUI;
% ---------------------------------------------------