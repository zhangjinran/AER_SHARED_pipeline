function varargout = load(varargin)
%LOAD Retry-enabled compatibility wrapper for file-first MATLAB load calls.
%   With an output, behaves like built-in LOAD and returns a struct.
%   With no output, assigns loaded variables into the caller workspace.
%   The underlying built-in is called by load_with_nas_retry via BUILTIN,
%   preventing recursion. This gives retained direct load(...) calls in the
%   new-root pipeline the same NAS retry and logging behavior.

    if nargout > 1
        error('load:TooManyOutputs', 'MATLAB load supports at most one output.');
    end
    if isempty(varargin)
        error('load:MissingInput', 'A MAT-file path is required.');
    end

    S = load_with_nas_retry(varargin{:});
    if nargout == 1
        varargout{1} = S;
        return
    end

    names = fieldnames(S);
    for k = 1:numel(names)
        assignin('caller', names{k}, S.(names{k}));
    end
end
