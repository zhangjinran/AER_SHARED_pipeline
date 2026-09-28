function output_path = build_chapter5_type_number_column_day(stats_path, ap_day_path, output_path)
%BUILD_CHAPTER5_TYPE_NUMBER_COLUMN_DAY Build a 5x5 profile-column grid.
% Uses the already published Chapter5_v2 daily stats. Type-specific number
% values are preserved exactly: Type2 uses dust N100; Type5=dust N100+PC N50;
% Type7=dust N100+marine N50. Thus this is not a uniform-threshold N50 field.

if ~isfile(stats_path) || ~isfile(ap_day_path)
    error('CH5Column:MissingInput','Stats or canonical AP day MAT is missing.');
end
if ~isfile(fullfile(fileparts(stats_path),'_SUCCESS'))
    error('CH5Column:UnpublishedInput','Daily Chapter5_v2 stats lacks _SUCCESS.');
end
S = load_retry(stats_path,'CALIPSO_STATS_CH5_V2');
if ~isfield(S,'CALIPSO_STATS_CH5_V2'), error('CH5Column:Schema','Stats variable missing.'); end
C = S.CALIPSO_STATS_CH5_V2;
if ~strcmp(C.meta.schema_version,'calipso-stats-ch5-v2') || ...
        ~strcmp(C.meta.status,'candidate_unpublished')
    error('CH5Column:Schema','Unexpected Chapter5_v2 daily stats contract.');
end

% Use the altitude centers carried by canonical APro MAT metadata. The shared
% adapter treats these centers as km (it queries ERA5 at Height*1000 metres).
A = load_retry(ap_day_path,'day');
if ~isfield(A,'day') || isempty(A.day.files)
    error('CH5Column:APSchema','Canonical AP MAT has no day.files metadata.');
end
alt_km = double(A.day.files{1}.Lidar_Data_Altitudes(:));
if median(abs(alt_km),'omitnan') > 100, alt_km = alt_km ./ 1000; end
alt_km = sort(unique(alt_km(isfinite(alt_km))));
if numel(alt_km)<2 || any(diff(alt_km)<=0)
    error('CH5Column:AltitudeAxis','Canonical AP altitude axis is invalid.');
end
edge = zeros(numel(alt_km)+1,1);
edge(2:end-1) = (alt_km(1:end-1)+alt_km(2:end))/2;
edge(1) = alt_km(1)-(alt_km(2)-alt_km(1))/2;
edge(end) = alt_km(end)+(alt_km(end)-alt_km(end-1))/2;
dz_km = max(0,min(edge(2:end),10)-max(edge(1:end-1),0));

nlat=36; nlon=72; nd=2; ntype=7;
column_sum=zeros(nlat,nlon,nd,ntype+1);
profile_count=zeros(nlat,nlon,nd);
type_profile_count=zeros(nlat,nlon,nd,ntype);
sample_count=zeros(nlat,nlon,nd,ntype);
duplicate_profile_height_rows=0; unmatched_height_rows=0; accepted_rows=0;
months={'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
month_field=months{month(datetime_from_stats(C))};
dn_names={'Day','Night'};

for i=1:nlat
  for j=1:nlon
    for d=1:nd
      dn=dn_names{d};
      row_time=[]; row_lat=[]; row_lon=[]; row_h=[]; row_value=[]; row_type=[];
      for t=1:ntype
        tf=sprintf('Type%d',t);
        if ~isfield(C.grid(i,j),dn), continue; end
        if ~isfield(C.grid(i,j).(dn),month_field), continue; end
        block=C.grid(i,j).(dn).(month_field);
        if ~isfield(block,tf), continue; end
        T=block.(tf).data;
        if isempty(T), continue; end
        if ~all(ismember({'Time','Lat','Lon','Height','original_type','Nd_dry_OMCAM_v2'},T.Properties.VariableNames))
            error('CH5Column:TableSchema','A Type table lacks profile, height, type, or number-value columns.');
        end
        if any(double(T.original_type)~=t)
            error('CH5Column:TypeProvenance','Nested Type%d contains mismatched original_type rows.',t);
        end
        expected = chapter5_expected_value(T,t);
        actual = double(T.Nd_dry_OMCAM_v2(:));
        check = isfinite(expected) & isfinite(actual);
        scale = max(1,max(abs([expected(check);actual(check)])));
        if any(abs(expected(check)-actual(check)) > 1e-10*scale)
            error('CH5Column:TypeDefinition','Type%d values do not match the frozen Chapter5 component definition.',t);
        end
        h=double(T.Height(:)); [has_z,zi]=ismembertol(h,alt_km,1e-7,'DataScale',1);
        in_z=has_z & dz_km(max(1,zi))>0 & h>=0 & h<=10;
        unmatched_height_rows=unmatched_height_rows+nnz(~has_z & h>=0 & h<=10);
        valid=in_z & isfinite(double(T.Nd_dry_OMCAM_v2(:))) & double(T.Nd_dry_OMCAM_v2(:))>=0 & ...
            isfinite(double(T.Time(:))) & isfinite(double(T.Lat(:))) & isfinite(double(T.Lon(:)));
        if ~any(valid), continue; end
        row_time=[row_time;double(T.Time(valid))]; %#ok<AGROW>
        row_lat=[row_lat;round(double(T.Lat(valid)),8)]; %#ok<AGROW>
        row_lon=[row_lon;round(double(T.Lon(valid)),8)]; %#ok<AGROW>
        row_h=[row_h;zi(valid)]; %#ok<AGROW>
        row_value=[row_value;double(T.Nd_dry_OMCAM_v2(valid)).*dz_km(zi(valid))*1e5]; %#ok<AGROW>
        row_type=[row_type;repmat(t,nnz(valid),1)]; %#ok<AGROW>
        sample_count(i,j,d,t)=sample_count(i,j,d,t)+nnz(valid);
      end
      if isempty(row_time), continue; end
      [profile_key,~,profile_id]=unique([row_time,row_lat,row_lon],'rows','sorted');
      % One aerosol retrieval per original profile and vertical level is
      % expected; fail loudly instead of silently double-integrating pixels.
      pair=[profile_id,row_h,row_type];
      if size(unique(pair,'rows'),1)~=size(pair,1)
          duplicate_profile_height_rows=duplicate_profile_height_rows+1;
          error('CH5Column:DuplicateLayer','Duplicate profile/height/type samples in grid (%d,%d), daynight=%s.',i,j,dn);
      end
      nprof=size(profile_key,1);
      prof_type=zeros(nprof,ntype);
      lin=sub2ind([nprof,ntype],profile_id,row_type);
      prof_type(:)=accumarray(lin,row_value,[nprof*ntype,1],@sum,0);
      profile_count(i,j,d)=profile_count(i,j,d)+nprof;
      for t=1:ntype
          type_profile_count(i,j,d,t)=type_profile_count(i,j,d,t)+nnz(prof_type(:,t)>0);
          column_sum(i,j,d,t)=column_sum(i,j,d,t)+sum(prof_type(:,t));
      end
      column_sum(i,j,d,ntype+1)=column_sum(i,j,d,ntype+1)+sum(sum(prof_type,2));
      accepted_rows=accepted_rows+size(pair,1);
    end
  end
end

mean_column=nan(size(column_sum));
for d=1:nd
    denom=profile_count(:,:,d);
    for t=1:ntype+1
        x=column_sum(:,:,d,t); q=denom>0; x(q)=x(q)./denom(q); x(~q)=NaN;
        mean_column(:,:,d,t)=x;
    end
end
period_date=datetime_from_stats(C); period_date.Format='yyyy-MM-dd';
meta=struct('schema_version','chapter5-type-number-column-v1', ...
    'product_key','ch5-number-column__stats-ch5v2__omcam-v2__grid5deg__z0-10km-v1', ...
    'source_stats',stats_path,'source_ap_day_metadata',ap_day_path, ...
    'date',char(period_date),'grid_lat_deg',5,'grid_lon_deg',5, ...
    'altitude_min_km',0,'altitude_max_km',10,'integration','sum(Nd_cm-3 .* dz_km .* 1e5) per profile; grid value is mean across aerosol-bearing profiles', ...
    'output_units','cm-2','height_source_units','km','type_semantics', ...
    'Type1=marine_N50; Type2=dust_N100; Type3=PC_N50; Type4=CC_N50; Type5=dust_N100+PC_N50 within original sample; Type6=smoke_N50; Type7=dust_N100+marine_N50 within original sample', ...
    'is_uniform_N50',false,'component_order',{{'Type1','Type2','Type3','Type4','Type5','Type6','Type7','Total'}}, ...
    'daynight',{{'Day','Night'}},'rows_integrated',accepted_rows, ...
    'unmatched_height_rows_below_10km',unmatched_height_rows, ...
    'duplicate_profile_height_rows',duplicate_profile_height_rows, ...
    'vertical_layer_thickness_km',dz_km(:),'altitude_centers_km',alt_km(:));
N50_COLUMN_CH5_V2=struct('meta',meta,'column_sum_cm2',column_sum, ...
    'column_mean_cm2',mean_column,'profile_count',profile_count, ...
    'type_profile_count',type_profile_count,'sample_count',sample_count); %#ok<NASGU>
if ~isfolder(fileparts(output_path)),mkdir(fileparts(output_path));end
save(output_path,'N50_COLUMN_CH5_V2','-v7.3');
fprintf('N50_COLUMN_CH5_V2_PASS date=%s rows=%d profiles=%d output=%s\n', ...
    char(period_date),accepted_rows,sum(profile_count(:)),output_path);
end

function value=chapter5_expected_value(T,t)
switch t
    case 1, value=double(T.N50_marine(:));
    case 2, value=double(T.N100_dust(:));
    case 3, value=double(T.N50_polluted_continental(:));
    case 4, value=double(T.N50_clean_continental(:));
    case 5, value=double(T.N100_dust(:))+double(T.N50_polluted_continental(:));
    case 6, value=double(T.N50_elevated_smoke(:));
    case 7, value=double(T.N100_dust(:))+double(T.N50_marine(:));
end
end

function d=datetime_from_stats(C)
% Prefer source T_all basename; daily product dates are YYYYMMDD.
tok=regexp(C.meta.source_tall,'(\d{8})\.mat$','tokens','once');
if isempty(tok), error('CH5Column:Date','Cannot derive date from source_tall path.'); end
d=datetime(tok{1},'InputFormat','yyyyMMdd');
end

function S=load_retry(path,varname)
for k=1:5
    try
        S=builtin('load',path,varname); return
    catch ME
        if k==5, rethrow(ME); end
        fprintf(2,'READ_RETRY attempt=%d/5 file=%s error=%s\n',k,path,ME.message);
        pause(k*2);
    end
end
end
