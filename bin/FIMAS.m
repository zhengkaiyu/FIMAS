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
% set default colour scheme to black background and white font for dark
% room usage
set(0,'DefaultUicontrolBackgroundColor','k');
set(0,'DefaultUicontrolForegroundColor','w');
% ---------------------------------------------------
% version related initialisation for parallel computing
[ ver, date ] = version;
release_yr = str2double(datestr(date,'YYYY'));
switch release_yr
    case {2015,2016,2017,2018,2019}
        feature('accel','on');
    case {2008,2009,2010,2011,2012,2013,2014}
 
    otherwise
        errordlg(sprintf('Incompatible MATLAB Version.\nCurrent Version %s\nRequire >R2008a & <R2018a',ver),'Version Error','modal');
end
% ---------------------------------------------------
% profile -memory on;
% ---------------------------------------------------
% open main gui interface
MAIN_GUI;
% ---------------------------------------------------