function run_aod_apro_month(month_id,run_root)
addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));cfg=aod_apro_config();
assert(~isempty(regexp(month_id,'^\d{6}$','once')),'AOD:Date','Expected YYYYMM.');
assert(startsWith(lower(strrep(run_root,'/','\')),lower([fullfile(cfg.project_root,'runs','aod') filesep])),'AOD:Run','Run outside runs/aod.');
for name={'logs','reports','staging','plots','days'},mkdir_if_missing(fullfile(run_root,name{1}));end
try
    test_aod_apro_gate();test_pool();
    inventory_file=fullfile(run_root,'reports','frozen_inventory.mat');
    if isfile(inventory_file)
        S=load_aod_mat_retry(inventory_file,'inventory','frozen_month');
        assert(strcmp(S.frozen_month,month_id),'AOD:Inventory','Wrong frozen month.');inventory=S.inventory;
    else
        first=datetime([month_id '01'],'InputFormat','yyyyMMdd');dates=first:caldays(1):dateshift(first,'end','month');
        folder=fullfile(cfg.input_root,month_id(1:4));
        for attempt=1:5
            try
                assert(isfolder(folder),'AOD:NAS','Source folder unavailable.');
                listing=dir(fullfile(folder,[month_id(1:4) '_' month_id(5:6) '_*.mat']));
                assert(~isempty(listing),'AOD:NAS','Empty month listing requires inspection, not all-missing skip.');break;
            catch ME
                if attempt==5,rethrow(ME);end
                fprintf('AOD_LIST_RETRY %d %s\n',attempt,ME.message);pause(5);
            end
        end
        n=numel(dates);date=strings(n,1);path=date;status=date;bytes=zeros(n,1);
        for k=1:n
            date(k)=string(dates(k),'yyyyMMdd');name=[char(string(dates(k),'yyyy_MM_dd')) '.mat'];path(k)=string(fullfile(folder,name));
            j=find(strcmp({listing.name},name),1);
            if isempty(j),status(k)="MISSING_APRO";else
                assert(listing(j).bytes>0,'AOD:Input','Zero-byte raw input: %s',path(k));
                status(k)="READY";bytes(k)=listing(j).bytes;
            end
        end
        inventory=table(date,path,status,bytes);frozen_month=month_id;
        save(inventory_file,'inventory','frozen_month');writetable(inventory,fullfile(run_root,'reports','frozen_inventory.csv'));
    end
    fprintf('AOD_MONTH_INVENTORY month=%s ready=%d missing=%d\n',month_id,nnz(inventory.status=="READY"),nnz(inventory.status=="MISSING_APRO"));
    progress=inventory;progress.stage=inventory.status;
    G=[];sources=strings(0,1);sizes=zeros(0,1);qc=true;zero=0;
    for k=1:height(inventory)
        d=char(inventory.date(k));
        if inventory.status(k)~="READY",fprintf('AOD_MONTH_SKIP date=%s reason=%s\n',d,inventory.status(k));continue;end
        fprintf('AOD_MONTH_DAY_BEGIN date=%s\n',d);
        run_aod_apro_day(d,fullfile(run_root,'days',d),false);
        folder=fullfile(cfg.grid_root,d(1:4),d(5:6),d(7:8));p=fullfile(folder,['AOD_GRID_' d '.mat']);
        for f={['AOD_GRID_' d '.mat'],'manifest.txt','input_inventory.csv','_SUCCESS'}
            assert(isfile(fullfile(folder,f{1})),'AOD:Contract','Incomplete day: %s',d);
        end
        S=load_aod_mat_retry(p,'AOD_GRID');D=S.AOD_GRID;
        assert(strcmp(D.meta.product_key,cfg.grid_key)&&strcmp(D.meta.date,d),'AOD:Input','Day contract mismatch.');
        G=pool_aod_grids(G,D);qc=qc&&D.meta.qc_used;zero=zero+D.meta.zero_aerosol_profiles;
        sources(end+1,1)=string(p);info=dir(p);sizes(end+1,1)=info.bytes;
        progress.stage(k)="PASS";writetable(progress,fullfile(run_root,'reports','day_status.csv'));
        fprintf('AOD_MONTH_DAY_PASS date=%s completed=%d/%d\n',d,numel(sources),nnz(inventory.status=="READY"));
    end
    assert(numel(sources)==nnz(inventory.status=="READY")&&~isempty(G),'AOD:Gate','Not all READY dates passed.');
    G.meta=struct('product_key',cfg.month_key,'schema_version','aod-month-v2','date',month_id, ...
        'included_dates',inventory.date(inventory.status=="READY"),'missing_dates',inventory.date(inventory.status~="READY"), ...
        'source_grid_key',cfg.grid_key,'averaging',cfg.averaging,'qc_used',qc,'zero_aerosol_profiles',zero, ...
        'common_valid_profiles',sum(G.profile_count,'all'),'channels',{cfg.channels});
    target=fullfile(cfg.month_root,month_id(1:4),month_id(5:6));name=['AOD_GRID_MONTH_' month_id '.mat'];
    product=fullfile(target,name);
    if isfolder(target)
        for f={name,'manifest.txt','input_inventory.csv','_SUCCESS'},assert(isfile(fullfile(target,f{1})),'AOD:Publish','Incomplete existing month.');end
        S=load_aod_mat_retry(product,'AOD_GRID');old=S.AOD_GRID;
        assert(isequal(old.meta.included_dates,G.meta.included_dates)&&isequal(old.profile_count,G.profile_count)&&isequal(old.sum_direct_ext,G.sum_direct_ext)&&isequal(old.sum_component_reconstruction,G.sum_component_reconstruction),'AOD:Existing','Existing month differs; not overwritten.');
    else
        stage=fullfile(run_root,'staging',['month_' month_id]);assert(~isfolder(stage),'AOD:Publish','Inspect existing month staging.');mkdir(stage);
        AOD_GRID=G;save(fullfile(stage,name),'AOD_GRID','-v7.3');
        writetable(table(sources,sizes,'VariableNames',{'path','bytes'}),fullfile(stage,'input_inventory.csv'));
        fid=fopen(fullfile(stage,'manifest.txt'),'w');assert(fid>=0);fprintf(fid,'product_key=%s\nmonth=%s\nready_days=%d\nmissing_days=%d\naggregation=sum_daily_AOD_sums/sum_daily_profile_counts\npure_types_identical=true\nqc_used=%d\n',cfg.month_key,month_id,numel(sources),nnz(inventory.status~="READY"),qc);fclose(fid);
        fid=fopen(fullfile(stage,'_SUCCESS'),'w');assert(fid>=0);fprintf(fid,'PASS\n');fclose(fid);
        mkdir_if_missing(fileparts(target));[ok,msg]=movefile(stage,target);assert(ok,'AOD:Publish','%s',msg);
    end
    fprintf('AOD_MONTH_PUBLISHED %s profiles=%d\n',product,sum(G.profile_count,'all'));
    plot_aod_apro_day(product,fullfile(run_root,'plots'));
    fprintf('AOD_MONTH_COMPLETE month=%s days=%d occupied=%d pure_types_identical=true\n',month_id,numel(sources),nnz(G.profile_count));
catch ME
    fprintf(2,'AOD_MONTH_FAILED\n%s\n',getReport(ME,'extended','hyperlinks','off'));rethrow(ME);
end
end
function mkdir_if_missing(p)
if ~isfolder(p),mkdir(p);end
end
function test_pool()
D=struct('profile_count',uint32(1),'sum_direct_ext',zeros(1,1,8),'sum_component_reconstruction',zeros(1,1,8),'lat_edges',[0 5],'lon_edges',[0 5]);
D.sum_direct_ext(1,1,[1 8])=2;D.sum_component_reconstruction=D.sum_direct_ext;G=pool_aod_grids([],D);
D.profile_count=uint32(3);D.sum_direct_ext(1,1,[1 8])=12;D.sum_component_reconstruction=D.sum_direct_ext;G=pool_aod_grids(G,D);
assert(G.profile_count==4&&G.mean_direct_ext(1,1,1)==3.5,'AOD:PoolTest','Profile-weighted pooling failed.');
fprintf('AOD_POOL_TEST_PASS unequal_daily_counts=true\n');
end
