function name = layout_gate_id(branch)
%LAYOUT_GATE_ID Give every regression run its own never-reused test root.
    attempt = getenv('CODE_LAYOUT_GATE_ATTEMPT');
    assert(~isempty(regexp(attempt,'^[A-Za-z0-9_-]+$','once')), ...
        'LayoutGate:Attempt','Set a unique CODE_LAYOUT_GATE_ATTEMPT.');
    name = ['code_layout_' branch '_' attempt];
end
