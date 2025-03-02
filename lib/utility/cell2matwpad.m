function matrix = cell2matwpad(C, padValue)
%CELL2MATWPAD Summary of this function goes here
%   Detailed explanation goes here
% Convert a cell array of vectors/matrices to a matrix with padding
% Inputs:
%   C: Cell array of vectors/matrices
%   padValue: Value to use for padding (default is NaN)
% Output:
%   matrix: Padded matrix or 3D matrix

if nargin < 2
    padValue = NaN; % Default padding value
end

if iscell(C)
    if isvector(C{1})
        % For vectors
        maxLength = max(cellfun(@length, C));
        paddedC = cellfun(@(x) [x; padValue * ones(maxLength - length(x), 1)], C, 'UniformOutput', false);
        matrix = cat(2, paddedC{:});
    else
        % For matrices
        maxRows = max(cellfun(@(x) size(x, 1), C));
        maxCols = max(cellfun(@(x) size(x, 2), C));
        paddedC = cellfun(@(x) [x, padValue * ones(size(x, 1), maxCols - size(x, 2)); ...
            padValue * ones(maxRows - size(x, 1), maxCols)], C, 'UniformOutput', false);
        matrix = cat(2, paddedC{:});
    end
else
    matrix=C;
end