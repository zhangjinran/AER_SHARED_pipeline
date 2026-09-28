function test_geotime_fix()
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'functions'));
a=reshape(1:30,10,3);assert(isequal(calipso_profile_center(a,10),a(:,2)));assert(isequal(calipso_profile_center(a',10),a(:,2)));
assert(isequal(calipso_profile_center((1:10)',10),(1:10)'));
failed=false;try,calipso_profile_center(1:30,10);catch,failed=true;end;assert(failed,'Linearized ambiguous triplets must be rejected.');
m=struct('lon',[0 90 180 270],'lat',[90 0 -90]);
[x,y]=era5_spatial_indices([359.9;-0.1;180],[90;0;-90],m);assert(isequal(x,[1;1;3])&&isequal(y,[1;2;3]));
m.lon=[180 90 0 -90];m.lat=[-90 0 90];
[x,y]=era5_spatial_indices([359.9;-0.1;180],[90;0;-90],m);assert(isequal(x,[3;3;1])&&isequal(y,[3;2;1]));
fprintf('GEOTIME_UNIT_PASS center_layouts ambiguous_layout_rejected periodic_longitude reversed_axes\n');
end
