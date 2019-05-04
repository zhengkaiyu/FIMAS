function [ answer ] = askapplyall(question)
%ASKAPPLYALL Summary of this function goes here
%   Detailed explanation goes here

switch question
    case 'cancel'
        message='Cancel ALL';
    case 'apply'
        message='Apply to ALL';
end
button = questdlg(sprintf('%s?',message),'Multiple Selection',message,'Just this one',message) ;
switch button
    case message
        answer=false;
    case 'Just this one'
        answer=true;
    otherwise
        % action cancellation
        answer=false;
end
end