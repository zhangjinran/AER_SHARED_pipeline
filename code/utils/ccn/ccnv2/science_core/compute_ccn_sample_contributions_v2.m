function out = compute_ccn_sample_contributions_v2(T, extinction_n, cfg)
%COMPUTE_CCN_SAMPLE_CONTRIBUTIONS_V2 Frozen OMCAM-v2 sample calculation.
% Returns CCN020 component contributions in cm^-3.  No file I/O or gridding.

if nargin<3 || isempty(cfg), cfg=ccn_v2_config(); end
required={'Ext','Back','Depol','Type','RH'};
if ~istable(T) || ~all(ismember(required,T.Properties.VariableNames))
    error('CCNv2:Schema','T_all must contain %s.',strjoin(required,', '));
end
if ~isfinite(cfg.units.volume_scale_conversion)
    error('CCNv2:UnitGate','Production is blocked until the unit Gate passes.');
end

n=height(T); ext=double(T.Ext(:)); back=double(T.Back(:)); depol=double(T.Depol(:));
type=double(T.Type(:)); rh=double(T.RH(:));
contrib=zeros(n,5); alpha=zeros(n,5); valid=false(n,1);
is_type=isfinite(type) & type==round(type) & type>=1 & type<=7;
base=is_type & isfinite(ext) & ext>0 & isfinite(rh) & rh>=0 & rh<=99;

% Pure CALIPSO subtypes use their retrieved extinction directly.
pure_map=[1 1; 2 2; 3 3; 4 4; 6 5];
for q=1:size(pure_map,1)
    m=base & type==pure_map(q,1); alpha(m,pure_map(q,2))=ext(m); valid(m)=true;
end

% Mixed types use the frozen beta split and fixed component lidar ratios.
mixed=base & (type==5 | type==7) & isfinite(back) & back>0 & isfinite(depol);
if any(mixed)
    [bd,bn]=split_mixed_dust(back(mixed),depol(mixed),cfg);
    alpha(mixed,2)=cfg.lidar_ratio.dust.*bd;
    m5=mixed & type==5; m7=mixed & type==7;
    alpha(m5,3)=cfg.lidar_ratio.polluted_continental.*bn(type(mixed)==5);
    alpha(m7,1)=cfg.lidar_ratio.marine.*bn(type(mixed)==7);
    valid(mixed)=true;
end

fields={'CM','DU','PC','CC','SM'};
number_factor=zeros(1,5);
for q=1:5
    if ~isfield(extinction_n,fields{q}),error('CCNv2:PriorSchema','Missing prior field %s.',fields{q});end
    tab=double(extinction_n.(fields{q}));
    if size(tab,2)~=2, error('CCNv2:PriorSchema','Prior %s must have RH/extinction columns.',fields{q});end
    lookup=interp1(tab(:,1),tab(:,2),rh,'linear',NaN);
    has_alpha=alpha(:,q)>0;
    volume=zeros(n,1); volume(has_alpha)=alpha(has_alpha,q).*cfg.units.volume_scale_conversion./lookup(has_alpha);
    cutoff=cfg.cutoff_um.nondust; if q==2,cutoff=cfg.cutoff_um.dust;end
    number_factor(q)=integrate_number_per_unit_volume(cfg.parameters.(cfg.component_names{q}),cutoff,cfg.radius_max_um);
    contrib(:,q)=volume.*number_factor(q);
    valid=valid & (~has_alpha | (isfinite(contrib(:,q)) & contrib(:,q)>=0));
end
contrib(~valid,:)=0;
out=struct('ccn020_component_cm3',contrib,'ccn020_total_cm3',sum(contrib,2), ...
    'valid',valid,'component_alpha_km_inv',alpha,'number_factor',number_factor, ...
    'mixed_beta_conserved',mixed_beta_conserved(back,depol,type,mixed,cfg));
end

function ok=mixed_beta_conserved(back,depol,type,mixed,cfg)
ok=true;
if any(mixed)
    [bd,bn]=split_mixed_dust(back(mixed),depol(mixed),cfg);
    ok=max(abs((bd+bn)-back(mixed)))<1e-12;
end
end
