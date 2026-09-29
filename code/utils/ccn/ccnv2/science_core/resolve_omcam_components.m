function components = resolve_omcam_components(type, extinction, backscatter, depol, cfg)
%RESOLVE_OMCAM_COMPONENTS Convert one CALIPSO subtype sample to pure components.

if nargin < 5 || isempty(cfg)
    cfg = ccn_v2_config();
end
validateattributes(type, {'numeric'}, {'scalar','finite','integer','>=',1,'<=',7});
validateattributes(extinction, {'numeric'}, {'scalar','finite','positive'});

switch type
    case 1
        components = make_component('marine', extinction, type);
    case 2
        components = make_component('dust', extinction, type);
    case 3
        components = make_component('polluted_continental', extinction, type);
    case 4
        components = make_component('clean_continental', extinction, type);
    case 6
        components = make_component('elevated_smoke', extinction, type);
    case {5, 7}
        validateattributes(backscatter, {'numeric'}, {'scalar','finite','positive'});
        validateattributes(depol, {'numeric'}, {'scalar','finite'});
        [bd, bnd, regime] = split_mixed_dust(backscatter, depol, cfg);
        dust = make_component('dust', cfg.lidar_ratio.dust * bd, type);
        if type == 5
            nondust_name = 'polluted_continental';
            nondust_lr = cfg.lidar_ratio.polluted_continental;
        else
            nondust_name = 'marine';
            nondust_lr = cfg.lidar_ratio.marine;
        end
        nondust = make_component(nondust_name, nondust_lr * bnd, type);
        dust.depol_regime = regime;
        nondust.depol_regime = regime;
        components = [dust, nondust];
end
end

function s = make_component(name, alpha_ambient, source_type)
s = struct('component_type', name, ...
    'alpha_ambient', double(alpha_ambient), ...
    'source_type', double(source_type), ...
    'depol_regime', uint8(0));
end
