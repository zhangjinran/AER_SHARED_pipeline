function [ilon,ilat]=era5_spatial_indices(lon,lat,meta)
% Nearest actual coordinate; longitude is cyclic, including the 0/360 seam.
x=mod(double(meta.lon(:)),360); y=double(meta.lat(:));
assert(all(isfinite(x))&&all(isfinite(y))&&numel(unique(x))==numel(x)&&numel(unique(y))==numel(y),'ERA5:Coordinates','Invalid ERA5 axes.');
assert(all(isfinite(lon))&&all(isfinite(lat))&&all(abs(lat)<=90),'ERA5:Query','Invalid profile coordinate.');
[x,order]=sort(x);n=numel(x);
ilon=interp1([x(end)-360;x;x(1)+360],[order(end);order;order(1)],mod(double(lon),360),'nearest');
[y,order]=sort(y);
ilat=interp1(y,order,double(lat),'nearest',NaN);
assert(all(isfinite(ilon))&&all(isfinite(ilat)),'ERA5:Coverage','Coordinates outside ERA5 coverage.');
assert(all(ilon>=1&ilon<=n),'ERA5:Index','Bad longitude index.');
end
