function [ varargout ] = data2clip(input_data)
% data2clip copy various data type into clipboard
% cell format used so that different type of data can be processed
% simultaneously.
% data type include numerical matrices, strings, structured data,
% function handles, recursive cell data
%
% Usage: [_optional_output_] = data2clip(_data_to_be_copied_here_);
%       no output argument result in copy to clipboard
%       single output to have output to variable

%% function complete
% convert input to cell type for consistent processing
if ~iscell(input_data)
    input_data={input_data};
end

% convertion process
formatted_data=format_data(input_data);

% output
nout = max(nargout,0);
switch nout
    case 0
        % copy into clipboard
        clipboard('copy',formatted_data);
    case 1
        % output to variable
        varargout{1}=formatted_data;
end

%%
    function paste_data=format_data(raw)
        % recursive function to go through each cell and format data and
        % convert them into formatted string of tab seperated
        %#ok<*AGROW>
        paste_data=[];%initialise
        for idx=1:numel(raw)%loop through cell format
            data_size=size(raw{idx});
            if isnumeric(raw{idx})
                % numerical data require some formatting
                % create tab seperated data on the fly
                output_format=repmat([repmat('%g\t',1,data_size(1)-1),'%g\n'],1,data_size(2));
                % append data
                paste_data=[paste_data,sprintf(output_format,raw{idx})];
            elseif ischar(raw{idx})
                % string data output as is
                % output as it is a string but add carridge return on the end
                output_format='%s\n';
                paste_data=[paste_data,sprintf(output_format,raw{idx})];
            elseif iscell(raw{idx})
                % cell data will be recursively dived into
                paste_data=[paste_data,format_data(raw{idx})];
            elseif isstruct(raw{idx})
                % structured data will be converted to cell and dealt with
                paste_data=[paste_data,format_data(struct2cell(raw{idx}))];
            elseif isa(raw{idx}, 'function_handle')
                % function handle we can convert to string easily
                output_format='%s\n';
                paste_data=[paste_data,sprintf(output_format,func2str(raw{idx}))];
            else
                % can expand later to include other data types
                fprintf('cannot deal with this data types yet.\nOnly cells of numerical,string,function handle,structure,recursive cell data.\n');
            end
        end
    end
end