root = fileparts(mfilename('fullpath'));
S = load(fullfile(root,'CALIPSO_STATS_Monthly.mat'),'CALIPSO_STATS');
G = S.CALIPSO_STATS.grid;
months = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
dn = {'Day','Night'};
fid = fopen(fullfile(root,'CCN_global_data_diagnosis.txt'),'w');
fprintf(fid,'month,daynight,table_rows,finite_Nd,min_Nd,max_Nd,mean_Nd\n');
for m = 1:numel(months)
    for d = 1:numel(dn)
        rows=0; vals=[];
        for i=1:size(G,1)
            for j=1:size(G,2)
                if ~isfield(G(i,j),dn{d}) || ~isfield(G(i,j).(dn{d}),months{m}), continue; end
                M=G(i,j).(dn{d}).(months{m});
                for t=1:7
                    nm=sprintf('Type%d',t);
                    if isfield(M,nm) && isfield(M.(nm),'data')
                        T=M.(nm).data; rows=rows+height(T);
                        if ismember('Nd_dry_OMCAM',T.Properties.VariableNames)
                            x=T.Nd_dry_OMCAM; vals=[vals; x(isfinite(x))]; %#ok<AGROW>
                        end
                    end
                end
            end
        end
        if isempty(vals), mn=NaN; mx=NaN; av=NaN; else, mn=min(vals); mx=max(vals); av=mean(vals); end
        fprintf(fid,'%s,%s,%d,%d,%g,%g,%g\n',months{m},dn{d},rows,numel(vals),mn,mx,av);
    end
end
fclose(fid);
