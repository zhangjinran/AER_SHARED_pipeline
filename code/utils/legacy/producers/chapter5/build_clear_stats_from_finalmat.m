function out_mat_file=build_clear_stats_from_finalmat(final_mat_root,out_mat_file)
%BUILD_CLEAR_STATS_FROM_FINALMAT Build CLEAR_STATS from canonical Final MAT.
% Replaces the legacy HDF reader while preserving its AVD==1 statistics.
if nargin<1||isempty(final_mat_root), final_mat_root='\\DXP8800Pro-CRS\CALIPSO\CALIPSO_MAT_FINAL\CHAPTER5_AP\05kmAP'; end
if nargin<2||isempty(out_mat_file), out_mat_file=fullfile(pwd,'CLEAR_AIR_STATS_CALIPSO_Monthly_from_finalmat.mat'); end
if isfile(final_mat_root), files=dir(final_mat_root); else, files=dir(fullfile(final_mat_root,'**','*.mat')); files=files(~[files.isdir]); end; if isempty(files),error('No Final MAT files found');end
z_edges=(0:0.06:15)'; nb=numel(z_edges)-1; mons=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]; dn=["Day","Night"];
layers=[2 5 10]; CLEAR_STATS.grid=repmat(struct(),36,72);
for r=1:36,for c=1:72,for d=dn,for m=mons,CLEAR_STATS.grid(r,c).(d).(m)=struct('count_2km',0,'count_5km',0,'count_10km',0,'count_vert_prof',zeros(nb,1));end,end,end,end
for i=1:numel(files)
  S=load(fullfile(files(i).folder,files(i).name),'day'); if ~isfield(S.day,'files'),continue,end
  for j=1:numel(S.day.files)
    F=S.day.files{j}; avd=F.Atmospheric_Volume_Description(:,:,1); [np,nbin]=size(avd); if nbin~=399,continue,end
    lon=double(F.Longitude(:,2)); lat=double(F.Latitude(:,2)); t=double(F.Profile_Time(:,2)); if max(t)>1e6, t=t/86400+datenum(1993,1,1); else, t=t/86400+datenum(1993,1,1); end
    alt=double(F.Lidar_Data_Altitudes(:)); if numel(alt)~=nbin,continue,end
    clear_mask=bitand(avd(:),uint16(7))==1; [pp,zz]=find(reshape(clear_mask,np,nbin)); if isempty(pp),continue,end
    h=alt(zz); lo=lon(pp); la=lat(pp); tt=t(pp); [~,mo,~]=datevec(tt); L=max(1,min(72,ceil((lo+180)/5))); B=max(1,min(36,ceil((la+90)/5))); bi=discretize(h,z_edges); if contains(F.filename,'ZN')||contains(F.filename,'Night'), d='Night';else,d='Day';end
    for m=1:12, sm=mo==m; if ~any(sm),continue,end; mn=mons(m); for k=1:3, hm=sm&(h<=layers(k)); if any(hm),q=accumarray([B(hm),L(hm)],1,[36,72]);[rr,cc]=find(q);for x=1:numel(rr),fn=['count_' num2str(layers(k)) 'km']; CLEAR_STATS.grid(rr(x),cc(x)).(d).(mn).(fn)=CLEAR_STATS.grid(rr(x),cc(x)).(d).(mn).(fn)+q(rr(x),cc(x));end,end,end; vm=sm&~isnan(bi);if any(vm),q=accumarray([B(vm),L(vm),bi(vm)],1,[36,72,nb]);[rr,cc]=find(sum(q,3));for x=1:numel(rr),CLEAR_STATS.grid(rr(x),cc(x)).(d).(mn).count_vert_prof=CLEAR_STATS.grid(rr(x),cc(x)).(d).(mn).count_vert_prof+squeeze(q(rr(x),cc(x),:));end,end,end
  end
  fprintf('processed %d/%d: %s\n',i,numel(files),files(i).name);
end
meta=struct('source',final_mat_root,'criterion','bitand(Atmospheric_Volume_Description,7)==1','grid_deg',5,'vertical_edges_km',z_edges,'product_status','intermediate'); save(out_mat_file,'CLEAR_STATS','meta','-v7.3'); fprintf('WROTE %s\n',out_mat_file);
end
