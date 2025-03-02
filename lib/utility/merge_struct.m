function mergedStructArray = merge_struct(structArray1,structArray2)
% Get the names from both structured arrays
fields1 = fieldnames(structArray1);
fields2 = fieldnames(structArray2);


% Fill the merged structure with data from the first array
for i = 1:numel(fields1)
    mergedStructArray.(fields1{i}) = structArray1.(fields1{i});
end

% Fill the merged structure with data from the second array
for i = 1:numel(fields2)
    mergedStructArray.(fields2{i}) = structArray2.(fields2{i});
    mergedStructArray.(fields2{i}) = structArray2.(fields2{i});
end
