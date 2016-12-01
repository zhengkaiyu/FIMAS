function text_command( hObject )
% TEXT_COMMAND execute command in the handle string as matlab command
%   Generally used for edit box in GUI where the input text string can be
%   interpreted as Matlab command and executed results will be displayed in
%   the said edit box.
%   Syntax: text_command( object_handle )


%% function complete

% get current strings
val=get(hObject,'String');
if ischar(val)
    command{1}=val;
else
    command=val;
end

for m=1:length(command)
% loop through all lines
    if ~isempty(command{m})
    % contain something for this line
        if numel(command{m})>2
        % if it has more than one characters
            if strncmp(command{m}(1:2),'>>',2)
            % check if 1st line is a command
                expression=command{m}(3:end);%get the expression for command
                try
                    %try the command
                    if regexp(expression,'(global|=|help|;)')
                        %do not return if contain special symbols
                        eval(expression);
                    else
                        result=evalc(expression);
                        %print out command and results
                        if isnumeric(result)
                        % convert numerical result to strings
                            result=num2str(result);
                        end
                        % output command and its result
                        set(hObject,'String',[command;result]);
                    end
                catch exception
                % in case of error
                    errordlg({'Unable to comply',exception.message});
                end
            end
        end
    end
end