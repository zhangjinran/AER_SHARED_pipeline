function test_aod_apro_gate()
cfg=aod_apro_config(); n=6; b=3;
A=struct('filename','synthetic','Lidar_Data_Altitudes',[.15;.09;.03], ...
    'Longitude',zeros(n,3),'Latitude',zeros(n,3),'Profile_Time',repmat((1:n)',1,3), ...
    'Extinction_Coefficient_532',repmat([.1 .2 .3],n,1), ...
    'Total_Backscatter_Coefficient_532',.002*ones(n,b), ...
    'Particulate_Depolarization_Ratio_Profile_532',.18*ones(n,b), ...
    'Atmospheric_Volume_Description',ones(n,b,2,'uint16'));
flag=@(t) uint16(3+512*t);
A.Atmospheric_Volume_Description(1,1,:)=flag(1);
A.Atmospheric_Volume_Description(3,1,:)=flag(5);
A.Atmospheric_Volume_Description(4,1,1)=flag(1);
A.Atmospheric_Volume_Description(4,1,2)=flag(7);
A.Atmospheric_Volume_Description(5,1,:)=flag(1);
A.Atmospheric_Volume_Description(5,2,:)=flag(5);
A.Extinction_Coefficient_532(5,2)=2;
A.Atmospheric_Volume_Description(6,1,:)=flag(5);
A.Total_Backscatter_Coefficient_532(6,1)=NaN;
[P,g]=integrate_aod_apro_orbit(A,cfg);
assert(isequal(P.valid_for_grid,[true;true;true;true;false;false]));
assert(abs(P.aod_direct(1,1)-.006)<1e-12);
assert(all(P.aod_direct(2,:)==0));
assert(abs(P.aod_direct(4,1)-.003)<1e-12 && abs(P.aod_direct(4,7)-.003)<1e-12);
assert(P.valid_direct(6)&&~P.valid_reconstructed(6));
G=grid_aod_profiles(P,cfg);
assert(sum(G.profile_count,'all')==4);
assert(abs(G.mean_direct_ext(19,37,1)-.009/4)<1e-12,'AOD:ZeroDenominator','Zero profile not counted.');
assert(isequaln(G.mean_direct_ext(:,:,[1 2 3 4 6]),G.mean_component_reconstruction(:,:,[1 2 3 4 6])));
assert(all(isnan(G.mean_direct_ext(1,1,:))));
% An actual QC field must be applied, while non-aerosol QC fill is harmless.
A.Extinction_QC_Flag_532=zeros(n,b,2,'uint16'); A.Extinction_QC_Flag_532(1,1,:)=32;
Q=integrate_aod_apro_orbit(A,cfg); assert(~Q.valid_direct(1)&&Q.valid_direct(2));
% Unknown/no-signal is not a zero-aerosol observation.
A.Atmospheric_Volume_Description(2,1,1)=7;
Q=integrate_aod_apro_orbit(A,cfg); assert(~Q.valid_direct(2));
fprintf('AOD_APRO_UNIT_PASS full_profile_zero_denominator half_bin missing QC pure_invariance dz=%g\n',g.bin_thickness_km(1));
end
