function rh=match_era5_rh_orbit(raw, era_root)
%MATCH_ERA5_RH_ORBIT ERA5 时间与水平位置取最近邻，高度方向线性插值 RH。
% APRO 廓线中心取 N×3 经纬度和时间数组中的中间值。
np=size(raw.Extinction_Coefficient_532,1);
nb=size(raw.Extinction_Coefficient_532,2);
lon=double(raw.Longitude(:,2));lat=double(raw.Latitude(:,2));
sec=double(raw.Profile_Time(:,2));
utc=sec/86400+datenum(1993,1,1);
hour=round(utc*24)/24;
rh=nan(np,nb);
alt=double(raw.Lidar_Data_Altitudes(:))*1000;
for h=unique(hour(:))'
    stamp=datestr(h,'yyyymmdd_HH');
    path=fullfile(era_root,datestr(h,'yyyy'),datestr(h,'mm'), ...
        datestr(h,'dd'),sprintf('ERA5_%s.mat',stamp));
    if ~isfile(path),error('VSD:MissingERA5','Missing hourly ERA5: %s',path);end
    E=load(path,'ERA5'); era=E.ERA5;
    ex=mod(double(era.lon(:)),360);ey=double(era.lat(:));
    if any(~isfinite(ex))||any(~isfinite(ey))||numel(unique(ex))~=numel(ex)
        error('VSD:ERA5Axis','Invalid ERA5 geographic axis.');
    end
    [ex,ix]=sort(ex);[ey,iy]=sort(ey);
    profiles=find(hour==h);
    ilon=interp1([ex(end)-360;ex;ex(1)+360], ...
        [ix(end);ix;ix(1)],mod(lon(profiles),360),'nearest');
    ilat=interp1(ey,iy,lat(profiles),'nearest',NaN);
    for j=1:numel(profiles)
        if ~isfinite(ilon(j))||~isfinite(ilat(j)),continue;end
        p=profiles(j);
        eh=double(squeeze(era.height(ilon(j),ilat(j),:)));
        er=double(squeeze(era.RH(ilon(j),ilat(j),:)));
        if numel(eh)>=2&&all(isfinite(eh))&&all(diff(eh)>0)
            rh(p,:)=interp1(eh,er,alt,'linear',NaN);
        end
    end
    clear E era;
end
end
