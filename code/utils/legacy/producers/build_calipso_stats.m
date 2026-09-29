function output_path = build_calipso_stats(tall_path, output_path, varargin)
%BUILD_CALIPSO_STATS Build shared CALIPSO_STATS from a shared T_all MAT.
%   This is the extracted Step 2 producer used by Chapter 5.  Scientific
%   calculations intentionally follow the active inline implementation.

    p = inputParser;
    addRequired(p,'tall_path',@(x)ischar(x)||isstring(x));
    addRequired(p,'output_path',@(x)ischar(x)||isstring(x));
    parse(p,tall_path,output_path,varargin{:});
    tall_path=char(p.Results.tall_path);
    output_path=char(p.Results.output_path);

    if ~isfile(tall_path), error('build_calipso_stats:MissingTAll','Missing T_all: %s',tall_path); end
    S=load(tall_path,'T_all');
    if ~isfield(S,'T_all'), error('build_calipso_stats:MissingVariable','MAT has no T_all.'); end
    T_all=S.T_all;

    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(fullfile(root,'函数'));
    addpath(fullfile(root,'先验数据'));
    load('Lidar_Ratio_All.mat','Lidar_Ratio_All');
    Para_Particle=load('Parameter_Particle_CALISPO.mat');
    Ext_Norm=load('Extinction_Normalized.mat');
    RH_grid=1:100;
    month_names=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    nLat=36; nLon=72;

    CALIPSO_STATS=struct();
    CALIPSO_STATS.meta.grid_size=5;
    CALIPSO_STATS.meta.daynight={'Day','Night'};
    CALIPSO_STATS.meta.months=cellstr(month_names);
    CALIPSO_STATS.meta.aerosol_types=1:7;
    CALIPSO_STATS.meta.source_tall=tall_path;
    CALIPSO_STATS.meta.status='candidate_shared_until_gate_d';
    CALIPSO_STATS.grid(nLat,nLon)=struct();
    for i=1:nLat
        for j=1:nLon
            CALIPSO_STATS.grid(i,j).lat_range=[-90+(i-1)*5,-90+i*5];
            CALIPSO_STATS.grid(i,j).lon_range=[-180+(j-1)*5,-180+j*5];
        end
    end

    lat_idx=floor((T_all.Lat+90)/5)+1;
    lon_idx=floor((T_all.Lon+180)/5)+1;
    month_id=uint8(month(datetime(T_all.UTC,'ConvertFrom','datenum')));
    dn_id=zeros(height(T_all),1,'uint8');
    dn_id(T_all.DayNight=="Day")=1;
    dn_id(T_all.DayNight=="Night")=2;
    valid_g=(lat_idx>=1&lat_idx<=36)&(lon_idx>=1&lon_idx<=72)& ...
        (month_id>=1&month_id<=12)&(dn_id>0)&(T_all.Type>=1&T_all.Type<=7);
    T=T_all(valid_g,:);
    lat_idx=lat_idx(valid_g); lon_idx=lon_idx(valid_g);
    month_id=month_id(valid_g); dn_id=dn_id(valid_g);

    RH=T.RH;
    RH(RH<1)=1; RH(RH>100)=100;
    T.RH=RH;
    lr_mops=NaN(height(T),1);
    map_type=@(t)(t==1)*1+(t==2)*2+(t==3)*3+(t==4)*3+(t==6)*3;
    for a=1:7
        idx=T.Type==a;
        if ~any(idx), continue; end
        if a==5||a==7
            delta=T.Depol(idx);
            f_dust=(delta-0.05)*1.31./(0.26*(1+delta));
            f_dust=max(0,min(1,f_dust));
            LR_dust=interp1(RH_grid,Lidar_Ratio_All(2,:),RH(idx));
            if a==5, LR_nd=interp1(RH_grid,Lidar_Ratio_All(3,:),RH(idx));
            else, LR_nd=interp1(RH_grid,Lidar_Ratio_All(1,:),RH(idx)); end
            lr_mops(idx)=f_dust.*LR_dust+(1-f_dust).*LR_nd;
        else
            lr_mops(idx)=interp1(RH_grid,Lidar_Ratio_All(map_type(a),:),RH(idx));
        end
    end
    [Nd_dry,Nd_wet]=Calc_Nd_OMCAM(T,Para_Particle,Ext_Norm);
    bucket_id=sub2ind([36,72,2,12,7],lat_idx,lon_idx,double(dn_id),double(month_id),T.Type);
    [bucket_sorted,order]=sort(bucket_id);
    starts=[1;find(diff(bucket_sorted)~=0)+1];
    stops=[starts(2:end)-1;numel(bucket_sorted)];
    unique_bucket=bucket_sorted(starts);
    fprintf('valid rows=%d occupied buckets=%d\n',height(T),numel(unique_bucket));
    daynight_names=["Day","Night"];
    for g=1:numel(unique_bucket)
        idx=order(starts(g):stops(g));
        [i,j,dn_i,m_i,t_i]=ind2sub([36,72,2,12,7],unique_bucket(g));
        dn_str=daynight_names(dn_i); mn_str=month_names(m_i);
        tp_str=sprintf('Type%d',t_i);
        if ~isfield(CALIPSO_STATS.grid(i,j),dn_str), CALIPSO_STATS.grid(i,j).(dn_str)=struct(); end
        if ~isfield(CALIPSO_STATS.grid(i,j).(dn_str),mn_str), CALIPSO_STATS.grid(i,j).(dn_str).(mn_str)=struct(); end
        newData=table(T.Lon(idx),T.Lat(idx),T.UTC(idx),T.Height(idx), ...
            T.LR(idx),lr_mops(idx),T.RH(idx),T.Depol(idx),T.Ext(idx),T.Back(idx), ...
            Nd_dry(idx),Nd_wet(idx),'VariableNames', ...
            {'Lon','Lat','Time','Height','LidarRatio','lidar_ratio_mopsmap', ...
             'ERA5_RH','Depolarization_Ratio','Extinction','Backscatter', ...
             'Nd_dry_OMCAM','Nd_wet_OMCAM'});
        if ~isfield(CALIPSO_STATS.grid(i,j).(dn_str).(mn_str),tp_str)
            CALIPSO_STATS.grid(i,j).(dn_str).(mn_str).(tp_str).data=newData;
        else
            CALIPSO_STATS.grid(i,j).(dn_str).(mn_str).(tp_str).data= ...
                [CALIPSO_STATS.grid(i,j).(dn_str).(mn_str).(tp_str).data;newData];
        end
    end
    outdir=fileparts(output_path);
    if ~isempty(outdir)&&~isfolder(outdir), mkdir(outdir); end
    save(output_path,'CALIPSO_STATS','-v7.3');
    fprintf('CALIPSO_STATS saved: %s\n',output_path);
end
