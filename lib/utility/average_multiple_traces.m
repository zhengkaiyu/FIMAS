function [commonspace, interp_data, mean_data] = average_multiple_traces(traces, mode, normalise)
% AVERAGE_MULTIPLE_TRACES Align, interpolate, and average time-value traces
% Inputs:
%   traces     : Cell array of [time, value] matrices
%   mode       : Interpolation method ('linear' (default) | 'nearest' |
%   'next' | 'previous' | 'pchip' | 'cubic' | 'v5cubic' | 'makima' | 'spline')
%   normalise  : 'max' to normalize by peak, else none
% Outputs:
%   commonspace : Unified time axis starting at 0
%   interp_data : Interpolated/normalized traces (columns = traces)
%   mean_data   : NaN-robust mean across traces

% Handle inputs
if nargin < 2 || isempty(mode), mode = 'linear'; end
if nargin < 3, normalise = false; end

% Initialize outputs in case of early return
commonspace = [];
interp_data = [];
mean_data = [];

% Check input type and remove empty traces
if ~iscell(traces), return; end
traces = traces(cellfun(@(x) ~isempty(x), traces));
if isempty(traces), return; end

% Preprocess: align time to 0 and store values
preprocessed = cell(size(traces));
for k = 1:numel(traces)
    x = traces{k};
    t_shifted = x(:,1) - x(1,1); % Compute once per trace
    preprocessed{k} = struct('t', t_shifted, 'y', x(:,2));
end

% Build common time axis from all shifted times
all_times = cellfun(@(p) p.t, preprocessed, 'UniformOutput', false);
commonspace = unique(cat(1, all_times{:})); % Sorted unique times

% Preallocate and interpolate
n_traces = numel(preprocessed);
n_points = numel(commonspace);
interp_data = NaN(n_points, n_traces); % Handle out-of-range via NaN

for k = 1:n_traces
    p = preprocessed{k};
    [t_unique, idx] = unique(p.t); % Ensure monotonic for interp1
    interp_data(:,k) = interp1(t_unique, p.y(idx), commonspace, mode);
end

% Optional normalization
if strcmpi(normalise, 'max')
    max_vals = max(interp_data, [], 1, 'omitnan');
    interp_data = interp_data ./ max_vals;
end

% Compute robust mean (ignores NaNs)
mean_data = mean(interp_data, 2, 'omitnan');
end