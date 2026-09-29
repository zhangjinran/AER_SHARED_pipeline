function test_ccn_v2_routing_gate()
%TEST_CCN_V2_ROUTING_GATE Deterministic Gate for routing, split and RH lookup.

code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
root = fullfile(code_root,'utils','ccn','ccnv2');
addpath(fullfile(root,'config'),'-begin');
addpath(fullfile(root,'science_core'),'-begin');
cfg = ccn_v2_config();

back = [1 1 1];
depol = [0.04 0.18 0.32];
[bd,bn,regime] = split_mixed_dust(back,depol,cfg);
assert(isequal(regime,uint8([1 2 3])));
assert(bd(1)==0 && bn(1)==1);
assert(bd(3)==1 && bn(3)==0);
assert(max(abs((bd+bn)-back)) < 1e-12);

c5 = resolve_omcam_components(5,0.1,0.002,0.18,cfg);
assert(strcmp(c5(1).component_type,'dust'));
assert(strcmp(c5(2).component_type,'polluted_continental'));
c7 = resolve_omcam_components(7,0.1,0.002,0.18,cfg);
assert(strcmp(c7(1).component_type,'dust'));
assert(strcmp(c7(2).component_type,'marine'));

tab = [0 100; 50 200; 99 300];
got = lookup_normalized_extinction(tab,[0 25 50 99 100]);
assert(isequaln(got,[100 150 200 300 NaN]));

assert(cfg.units.volume_scale_conversion==1e9);
assert(strcmp(cfg.units.status,'VALIDATED_UNIT_GATE_V1'));
fprintf('CCN_V2_ROUTING_GATE PASS\n');
end
