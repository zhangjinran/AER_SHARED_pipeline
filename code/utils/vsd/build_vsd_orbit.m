function [records, diagnostics] = build_vsd_orbit(raw, rh, prior, cfg)
%BUILD_VSD_ORBIT 将一条 APRO HDF 轨道转换为参数式干态 VSD 记录。
% 输入 rh 是已匹配 APRO 位置的 ERA5 相对湿度，形状为 [廓线,bin]，单位为 %。
% 列式结构中的每一行对应一条 bin/组分逻辑记录。source_hdf 使用分类列，
% 既保留逐记录来源，又避免数百万次重复存储长文件名。VSD 保存组分身份和
% volume_um3_cm3；在任意以 µm 为单位的干态半径轴上可计算 volume*q_component(r)。
ext=double(raw.Extinction_Coefficient_532);
back=double(raw.Total_Backscatter_Coefficient_532);
dep=double(raw.Particulate_Depolarization_Ratio_Profile_532);
avd=uint16(raw.Atmospheric_Volume_Description(:,:,1)); % 取顺序上的第一个 AVD plane
[np,nb]=size(ext);
if ~isequal(size(back),[np nb],size(dep),size(avd),size(rh))
    error('VSD:InputShape','APRO and ERA5 RH must be profile-by-bin.');
end
lon=profile_center(raw.Longitude,np); lat=profile_center(raw.Latitude,np);
time=profile_center(raw.Profile_Time,np)/86400+datenum(1993,1,1);
z=double(raw.Lidar_Data_Altitudes(:)');
if numel(z)~=nb,error('VSD:AltitudeShape','Altitude axis/bin mismatch.');end
feature=bitand(avd,uint16(7));
type=double(bitand(bitshift(avd,-9),uint16(7)));
type(feature~=3)=0;
% 反演有效性与是否含气溶胶不同：无气溶胶的 type=0 bin 始终保留。
% Feature=3 且 subtype=0 表示未分类气溶胶，不属于晴空。
is_aero=feature==3;
base=isfinite(ext)&ext>0 & isfinite(rh)&rh>=0&rh<=99;
pure=is_aero & type~=5 & type~=7 & base;
mixed=is_aero & (type==5 | type==7) & base & ...
    isfinite(back)&back>0 & isfinite(dep)&dep>=0;
diagnostics=struct('source_hdf',char(raw.filename),'profiles',np, ...
    'bins',np*nb,'no_aerosol_bins',nnz(~is_aero), ...
    'aerosol_bins',nnz(is_aero),'invalid_aerosol_bins',nnz(is_aero & ~(pure|mixed)), ...
    'mixed_bins',nnz(mixed));
% 按最大记录数预分配；每个混合类型 bin 额外增加一条组分记录。
n=nnz(~is_aero|pure|mixed)+nnz(mixed);
records=struct('source_hdf',categorical(ones(n,1),1,{char(raw.filename)}), ...
    'profile_id',zeros(n,1,'uint32'),'sample_id',zeros(n,1,'uint16'), ...
    'longitude',zeros(n,1),'latitude',zeros(n,1),'time_datenum_utc',zeros(n,1), ...
    'height_center_km',zeros(n,1),'type',zeros(n,1,'uint8'), ...
    'component_id',zeros(n,1,'uint8'),'volume_um3_cm3',zeros(n,1));
keep=find(~is_aero|pure|mixed); k=numel(keep);
[p,b]=ind2sub([np nb],keep);
records.profile_id(1:k)=uint32(p); records.sample_id(1:k)=uint16(b);
records.longitude(1:k)=lon(p); records.latitude(1:k)=lat(p);
records.time_datenum_utc(1:k)=time(p); records.height_center_km(1:k)=z(b);
records.type(1:k)=uint8(type(keep));
% 组分编号遵循 cfg.components；编号 0 表示无气溶胶，其 VSD 恒为零。
mapping=uint8([0 1 2 3 4 0 5 0]);
records.component_id(1:k)=mapping(double(records.type(1:k))+1);
for t=[1 2 3 4 6]
    q=find(type(keep)==t);
    if isempty(q),continue;end
    name=cfg.components{double(mapping(t+1))};
    records.volume_um3_cm3(q)=invert_dry_vsd_volume(ext(keep(q)),rh(keep(q)), ...
        prior.(name),cfg.volume_scale_conversion);
end
% 对每个原始物理 bin 分别重建混合类型的尘与非尘消光系数。
mixpos=find(type(keep)==5|type(keep)==7); mi=keep(mixpos);
if ~isempty(mi)
    beta=back(mi); delta=dep(mi);
    fraction=zeros(size(beta)); fraction(delta>cfg.depol_dust)=1;
    middle=delta>=cfg.depol_nondust & delta<=cfg.depol_dust;
    fraction(middle)=((delta(middle)-cfg.depol_nondust).*(1+cfg.depol_dust))./ ...
        ((cfg.depol_dust-cfg.depol_nondust).*(1+delta(middle)));
    if any(fraction<0|fraction>1),error('VSD:MixedSplit','Invalid dust fraction.');end
    bd=beta.*fraction; bn=beta-bd;
    records.component_id(mixpos)=2;
    records.volume_um3_cm3(mixpos)=invert_dry_vsd_volume( ...
        cfg.lidar_ratio.dust.*bd,rh(mi),prior.dust,cfg.volume_scale_conversion);
    extra=k+(1:numel(mi));
    records.profile_id(extra)=records.profile_id(mixpos);
    records.sample_id(extra)=records.sample_id(mixpos);
    records.longitude(extra)=records.longitude(mixpos);
    records.latitude(extra)=records.latitude(mixpos);
    records.time_datenum_utc(extra)=records.time_datenum_utc(mixpos);
    records.height_center_km(extra)=records.height_center_km(mixpos);
    records.type(extra)=records.type(mixpos);
    is5=type(mi)==5;
    records.component_id(extra(is5))=3;
    records.component_id(extra(~is5))=1;
    if any(is5)
        records.volume_um3_cm3(extra(is5))=invert_dry_vsd_volume( ...
            cfg.lidar_ratio.polluted_continental.*bn(is5),rh(mi(is5)), ...
            prior.polluted_continental,cfg.volume_scale_conversion);
    end
    if any(~is5)
        records.volume_um3_cm3(extra(~is5))=invert_dry_vsd_volume( ...
            cfg.lidar_ratio.marine.*bn(~is5),rh(mi(~is5)), ...
            prior.marine,cfg.volume_scale_conversion);
    end
end
diagnostics.output_records=n;
diagnostics.output_aerosol_bins=nnz(pure|mixed);
if any(~isfinite(records.volume_um3_cm3))
    error('VSD:InvalidVolume','Nonfinite retrieved dry VSD volume.');
end
end

function center=profile_center(value,n)
% APRO 每条廓线的坐标与时间各有三个值，此处取中间值。
if isequal(size(value),[n 3]),center=double(value(:,2));
elseif isequal(size(value),[3 n]),center=double(value(2,:)');
else,error('VSD:ProfileShape','Expected a profile triplet matrix.');end
end
