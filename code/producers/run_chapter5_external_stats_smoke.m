function R=run_chapter5_external_stats_smoke(stats_path)
if ~isfile(stats_path), error('Chapter5:MissingExternalStats','External CALIPSO_STATS not found: %s',stats_path); end
S=load(stats_path,'CALIPSO_STATS');
if ~isfield(S,'CALIPSO_STATS'), error('Chapter5:InvalidExternalStats','External file does not contain CALIPSO_STATS.'); end
C=S.CALIPSO_STATS; months={'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
R=struct('path',stats_path,'occupied',0,'rows',0,'finite_height',0,'finite_nd',0,'finite_positive_nd',0);
for i=1:36, for j=1:72
    if ~isfield(C.grid(i,j),'Day'), continue; end
    for m=1:12
        if ~isfield(C.grid(i,j).Day,months{m}), continue; end
        M=C.grid(i,j).Day.(months{m});
        for t=1:7
            tp=sprintf('Type%d',t); if ~isfield(M,tp), continue; end
            T=M.(tp).data; R.occupied=R.occupied+1; R.rows=R.rows+height(T);
            R.finite_height=R.finite_height+nnz(isfinite(T.Height));
            R.finite_nd=R.finite_nd+nnz(isfinite(T.Nd_dry_OMCAM));
            R.finite_positive_nd=R.finite_positive_nd+nnz(isfinite(T.Nd_dry_OMCAM)&T.Nd_dry_OMCAM>0);
        end
    end
end, end
fprintf('EXTERNAL_STATS_PATH=%s\n',stats_path);
fprintf('INTERNAL_STEP_2=SKIPPED\n');
fprintf('FIGURE5_CONTRACT occupied=%d rows=%d finite_height=%d finite_Nd=%d positive_Nd=%d\n',R.occupied,R.rows,R.finite_height,R.finite_nd,R.finite_positive_nd);
end
