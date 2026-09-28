function inspect_apro_aod_input(input_path)
S=load(input_path,'day'); D=S.day;
fprintf('DAY_FIELDS %s\n',strjoin(fieldnames(D),','));
fprintf('ORBIT_COUNT %d\n',numel(D.files));
A=D.files{1}; names=fieldnames(A);
for i=1:numel(names)
    x=A.(names{i}); fprintf('FIELD %s class=%s size=%s\n',names{i},class(x),mat2str(size(x)));
end
h=double(A.Lidar_Data_Altitudes(:));
fprintf('HEIGHT count=%d first=%g last=%g min_step=%g max_step=%g\n',numel(h),h(1),h(end),min(abs(diff(h))),max(abs(diff(h))));
disp(h([1:5,end-4:end])');
for n={'Extinction_QC_Flag_532','Atmospheric_Volume_Description','Surface_Elevation_Statistics'}
    if isfield(A,n{1})
        x=A.(n{1}); [u,~,g]=unique(x(:)); c=accumarray(g,1); [~,ix]=sort(c,'descend');
        ix=ix(1:min(20,numel(ix))); fprintf('VALUES %s [value,count]\n',n{1}); disp([double(u(ix)) double(c(ix))]);
    end
end
end
