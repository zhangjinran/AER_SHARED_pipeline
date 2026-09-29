root='F:\AER_RETRA_CASE'; day=fullfile(root,'CCN_FULL_RERUN_20260821','day_20220601'); ds=dir(fullfile(day,'orbit_*','CCN_grid.mat')); assert(numel(ds)==29);
S=zeros(36,72,3); C=zeros(36,72); total=0; valid=0;
for k=1:numel(ds), A=load(fullfile(ds(k).folder,ds(k).name)); S=S+A.sumC; C=C+A.cnt; total=total+A.total; valid=valid+A.valid; end
M=nan(36,72,3); for q=1:3, z=S(:,:,q); z(C>0)=z(C>0)./C(C>0); M(:,:,q)=z; end
save(fullfile(day,'CCN_2022_06_01_grid.mat'),'M','C','total','valid','-v7.3');
lon=-177.5:5:177.5; lat=-87.5:5:87.5; f=figure('Color','w','Position',[50 80 1500 430]); ss=[.15 .25 .40];
for q=1:3, subplot(1,3,q); imagesc(lon,lat,M(:,:,q)); set(gca,'YDir','normal'); axis tight equal; xlabel('Longitude'); ylabel('Latitude'); title(sprintf('CCN %.2f%% - 2022-06-01',ss(q))); colorbar; end
sgtitle('Global 5°x5° CCN distribution'); exportgraphics(f,fullfile(day,'CCN_2022_06_01_global.png'),'Resolution',180); close(f);
fprintf('total=%d valid=%d occupied_grid=%d\n',total,valid,nnz(C));
