function center=calipso_profile_center(value,n)
% Preserve native profile identity. Never reshape a triplet matrix linearly.
value=double(value);
if isequal(size(value),[n 3])
    center=value(:,2);
elseif isequal(size(value),[3 n]) && n~=3
    center=value(2,:)';
elseif isvector(value)&&numel(value)==n
    center=value(:);
else
    error('CALIPSO:ProfileShape','Expected N-by-3, 3-by-N or N samples; got %s for N=%d.',mat2str(size(value)),n);
end
end
