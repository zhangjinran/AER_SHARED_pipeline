function [P,geometry]=integrate_aod_apro_orbit(A,cfg)
% Full native profiles. AVD upper/lower planes each receive half a bin.
required={'filename','Lidar_Data_Altitudes','Longitude','Latitude','Profile_Time', ...
    'Atmospheric_Volume_Description','Extinction_Coefficient_532', ...
    'Total_Backscatter_Coefficient_532','Particulate_Depolarization_Ratio_Profile_532'};
assert(all(isfield(A,required)),'AOD:Schema','Missing required global APro field.');
h=double(A.Lidar_Data_Altitudes(:)); b=numel(h);
assert(b>=2 && all(isfinite(h)) && all(diff(h)<0),'AOD:Height','Expected descending native altitude centers.');
% Native CALIPSO grid has two resolutions. Derive the actual spacing within
% each regime and verify center-to-center distances, including the transition.
upper=h>cfg.altitude_transition_km; dz=zeros(b,1);
for zone=[false true]
    idx=find(upper==zone);
    if isempty(idx),continue;end
    assert(numel(idx)>=2,'AOD:Height','Insufficient centers in altitude regime.');
    w=median(abs(diff(h(idx)))); expected=0.06+0.12*double(zone);
    assert(abs(w-expected)<0.001,'AOD:Height','Unexpected APro vertical resolution.');
    dz(idx)=w;
end
assert(max(abs(abs(diff(h))-(dz(1:end-1)+dz(2:end))/2))<cfg.geometry_tolerance_km, ...
    'AOD:Height','Native centers do not match contiguous APro bin widths.');
ext=matrix(A.Extinction_Coefficient_532,b); n=size(ext,1);
back=matrix(A.Total_Backscatter_Coefficient_532,b);
depol=matrix(A.Particulate_Depolarization_Ratio_Profile_532,b);
avd=planes(A.Atmospheric_Volume_Description,n,b);
assert(isequal(size(ext),size(back),size(depol)),'AOD:Shape','Optical arrays differ.');
qc_present=isfield(A,'Extinction_QC_Flag_532');
if qc_present,qc=planes(A.Extinction_QC_Flag_532,n,b);else,qc=[];end
lon=profile_center(A.Longitude,n); lat=profile_center(A.Latitude,n);
time=profile_center(A.Profile_Time,n);
position_ok=isfinite(lon)&abs(lon)<=180&isfinite(lat)&abs(lat)<=90&isfinite(time)&time>=0;
direct=zeros(n,7); mixed=zeros(n,2); parts=zeros(n,4); independent=zeros(n,1);
naer=zeros(n,1); bad_ext=zeros(n,1); bad_beta=zeros(n,1); bad_qc=zeros(n,1);
unknown=zeros(n,1); strat=zeros(n,1); clouds=zeros(n,1); noclass=false(n,1);
avd_disagree=sum(avd(:,:,1)~=avd(:,:,2),2);
for plane=1:2
    flag=uint16(avd(:,:,plane)); feature=double(bitand(flag,uint16(7)));
    typ=double(bitand(bitshift(flag,-9),uint16(7)));
    aerosol=feature==3; classified=aerosol&typ>=1&typ<=7;
    ext_ok=isfinite(ext)&ext>=0&ext<=cfg.ext_max;
    if qc_present,qok=ismember(double(qc(:,:,plane)),cfg.qc_accept);else,qok=true(n,b);end
    beta_ok=isfinite(back)&back>=0&back<=cfg.back_max&isfinite(depol)&depol>=0&depol<=1;
    naer=naer+sum(aerosol,2); bad_ext=bad_ext+sum(aerosol&~ext_ok,2);
    bad_qc=bad_qc+sum(aerosol&~qok,2);
    unknown=unknown+sum(feature==0|feature==7,2);
    strat=strat+sum(feature==4,2); clouds=clouds+sum(feature==2,2);
    noclass=noclass|any(aerosol&~classified,2);
    use=classified&ext_ok&qok;
    layer=zeros(n,b); layer(use)=ext(use); layer=layer.*(dz'/2);
    independent=independent+sum(layer,2);
    for t=1:7
        selected=layer; selected(typ~=t)=0;
        direct(:,t)=direct(:,t)+sum(selected,2);
    end
    for k=1:2
        t=5+2*(k-1); is_type=classified&typ==t;
        bad_beta=bad_beta+sum(is_type&~beta_ok,2);
        use_mix=use&typ==t&beta_ok;
        alpha_d=zeros(n,b); alpha_nd=zeros(n,b);
        if any(use_mix,'all')
            [bd,bn]=split_mixed_dust(back(use_mix),depol(use_mix),cfg.ccn);
            lr=cfg.ccn.lidar_ratio.polluted_continental;
            if t==7,lr=cfg.ccn.lidar_ratio.marine;end
            alpha_d(use_mix)=bd*cfg.ccn.lidar_ratio.dust;
            alpha_nd(use_mix)=bn*lr;
        end
        d=sum(alpha_d.*(dz'/2),2); nd=sum(alpha_nd.*(dz'/2),2);
        parts(:,2*k-1)=parts(:,2*k-1)+d; parts(:,2*k)=parts(:,2*k)+nd;
        mixed(:,k)=mixed(:,k)+d+nd;
    end
end
% Unknown/no-signal is not clear air. Types 1..7 describe tropospheric
% aerosol: a profile containing unsupported stratospheric aerosol is flagged,
% rather than silently counting that aerosol as zero.
valid_direct=position_ok&bad_ext==0&bad_qc==0&unknown==0&strat==0&~noclass;
valid_reconstructed=valid_direct&bad_beta==0;
residual=max(abs(independent-sum(direct,2)));
assert(residual<1e-10,'AOD:Partition','Direct column differs from category sum.');
total=independent;
reconstructed_total=sum(direct(:,[1 2 3 4 6]),2)+sum(mixed,2);
direct=[direct,total]; direct(~valid_direct,:)=NaN;
mixed=[mixed,reconstructed_total]; mixed(~valid_reconstructed,:)=NaN;
parts(~valid_reconstructed,:)=NaN;
P=struct('profile_index',uint32((1:n)'), 'longitude',lon,'latitude',lat, ...
    'profile_time_tai_seconds',time,'aod_direct',direct, ...
    'aod_reconstructed_5_7_total',mixed,'mixed_component_aod',parts, ...
    'valid_direct',valid_direct,'valid_reconstructed',valid_reconstructed, ...
    'valid_for_grid',valid_direct&valid_reconstructed, ...
    'aerosol_subbin_count',uint16(naer),'invalid_ext_subbin_count',uint16(bad_ext), ...
    'invalid_mixed_subbin_count',uint16(bad_beta),'invalid_qc_subbin_count',uint16(bad_qc), ...
    'unknown_subbin_count',uint16(unknown),'stratospheric_subbin_count',uint16(strat), ...
    'cloud_subbin_count',uint16(clouds),'unclassified_aerosol',noclass, ...
    'avd_plane_disagreement_bins',uint16(avd_disagree));
geometry=struct('height_km',h,'bin_thickness_km',dz,'qc_present',qc_present, ...
    'direct_partition_maxdiff',residual);
end

function x=matrix(x,b)
x=double(x);
assert(ismatrix(x),'AOD:Shape','Expected two-dimensional optical data.');
if size(x,2)~=b && size(x,1)==b,x=x';end
assert(size(x,2)==b,'AOD:Shape','Altitude dimension mismatch.');
end
function x=planes(x,n,b)
if isequal(size(x),[2 b n]),x=permute(x,[3 2 1]);end
assert(isequal(size(x),[n b 2]),'AOD:Shape','Expected profile x altitude x two sub-bins.');
end
function x=profile_center(x,n)
x=double(x);
if isequal(size(x),[3 n]),x=x';end
assert(isequal(size(x),[n 3]),'AOD:Shape','Expected native profile triplets.');
x=x(:,2);
end
