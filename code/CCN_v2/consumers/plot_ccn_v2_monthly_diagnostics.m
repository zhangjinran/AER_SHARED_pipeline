function outputs=plot_ccn_v2_monthly_diagnostics(monthly_path, output_dir, render_method, display_label)
%PLOT_CCN_V2_MONTHLY_DIAGNOSTICS Plot-only v2 consumer; never recomputes OMCAM.
if nargin<3 || isempty(render_method),render_method='smooth_surface';end
if ~ismember(render_method,{'smooth_surface','contour'}),error('CCNv2:RenderMethod','render_method must be smooth_surface or contour.');end
if ~isfile(monthly_path),error('CCNv2:MissingMonth','Missing monthly product.');end
if ~isfolder(output_dir),mkdir(output_dir);end
this=fileparts(mfilename('fullpath'));v2root=fileparts(this);project_root=fileparts(fileparts(v2root));
addpath(fullfile(v2root,'config'),'-begin');addpath(fullfile(project_root,'plots','common'),'-begin');cfg=ccn_v2_config();
S=load(monthly_path,'sum_component','sum_total','sample_count','meta');
yyyymm='';
if isfield(S.meta,'yyyymm'),yyyymm=char(string(S.meta.yyyymm));end
if isempty(yyyymm)
 [~,stem]=fileparts(monthly_path);tok=regexp(stem,'(\d{6})','tokens','once');
 if isempty(tok),error('CCNv2:MonthLabel','Cannot resolve YYYYMM from monthly product.');end
 yyyymm=tok{1};
end
product_tag=yyyymm;
range_tok=regexp(yyyymm,'^(\d{6})_(\d{6})$','tokens','once');
if ~isempty(range_tok)
 month_label=sprintf('%s-%s to %s-%s',range_tok{1}(1:4),range_tok{1}(5:6),range_tok{2}(1:4),range_tok{2}(5:6));
 product_tag=yyyymm;
elseif numel(yyyymm)==6
 month_label=sprintf('%s-%s',yyyymm(1:4),yyyymm(5:6));
else
 month_label=yyyymm;
end
if nargin>=4 && ~isempty(display_label),month_label=display_label;end
cnt2=sum(S.sample_count,3); total2=squeeze(sum(S.sum_total,3)); comp2=squeeze(sum(S.sum_component,3));
mt=nan(size(total2));mc=nan(size(comp2));
for b=1:3
 z=total2(:,:,b);z(cnt2>0)=z(cnt2>0)./cnt2(cnt2>0);mt(:,:,b)=z;
 for q=1:5,z=comp2(:,:,q,b);z(cnt2>0)=z(cnt2>0)./cnt2(cnt2>0);mc(:,:,q,b)=z;end
end
lat=-89:2:89;lon=-177.5:5:177.5;names={'Marine','Dust','Polluted continental','Clean continental','Elevated smoke'};outputs=struct();
% Total and component maps use separately fixed CCN concentration ranges.
total_limits=[3 log10(500000)]; component_limits=[2 5];
f=figure('Visible','off','Color','w','Position',[50 30 1450 1050]);tiledlayout(2,2,'TileSpacing','compact','Padding','compact');colormap(f,turbo(35));
fprintf('CCN_V2_PLOT_STAGE total_maps %s\n',yyyymm);
fprintf('CCN_V2_RENDER_METHOD %s\n',render_method);
mapAx=[];for b=1:3,nexttile;mapAx=draw_global_robinson(to_log_map(mt(:,:,b),total_limits),lat,lon,total_limits,sprintf('Total CCN %.2f%%',cfg.supersaturation_percent(b)),false,render_method);end
nexttile;axis off;text(.05,.80,sprintf('%s CCN OMCAM v2',month_label),'FontSize',18,'FontWeight','bold');text(.05,.62,'2°×5° grid; pooled conditional mean','FontSize',12);text(.05,.46,'Aerosol-valid samples form the denominator','FontSize',11);cb=colorbar(mapAx);cb.Layout.Tile='east';cb.Label.String='CCN (cm^{-3})';cb.Ticks=[3 4 5 log10(500000)];cb.TickLabels={'1000','10000','100000','500000'};
outputs.total=fullfile(output_dir,sprintf('CCN_V2_%s_total.png',product_tag));exportgraphics(f,outputs.total,'Resolution',250);close(f);
f=figure('Visible','off','Color','w','Position',[30 30 1750 900]);tiledlayout(2,3,'TileSpacing','compact','Padding','compact');colormap(f,turbo(35));
fprintf('CCN_V2_PLOT_STAGE component_maps %s\n',yyyymm);
mapAx=[];for q=1:5,nexttile;mapAx=draw_global_robinson(to_log_map(mc(:,:,q,2),component_limits),lat,lon,component_limits,sprintf('%s, CCN 0.25%%',names{q}),false,render_method);end
nexttile;axis off;text(.05,.75,'Five v2 components','FontSize',16,'FontWeight','bold');text(.05,.55,'Pooled conditional mean','FontSize',12);cb=colorbar(mapAx);cb.Layout.Tile='east';cb.Label.String='CCN (cm^{-3})';cb.Ticks=component_limits(1):component_limits(2);cb.TickLabels={'100','1000','10000','100000'};
outputs.components=fullfile(output_dir,sprintf('CCN_V2_%s_components_ccn025.png',product_tag));exportgraphics(f,outputs.components,'Resolution',250);close(f);
f=figure('Visible','off','Color','w','Position',[30 30 1750 900]);tiledlayout(2,3,'TileSpacing','compact','Padding','compact');colormap(f,turbo(35));
fprintf('CCN_V2_PLOT_STAGE fraction_maps %s\n',yyyymm);
mapAx=[];for q=1:5,nexttile;frac=mc(:,:,q,2)./mt(:,:,2);frac(~isfinite(frac))=0;mapAx=draw_global_robinson(frac,lat,lon,[0 1],sprintf('%s fraction, CCN 0.25%%',names{q}),false,render_method);end
nexttile;axis off;text(.05,.75,'Component contribution fractions','FontSize',16,'FontWeight','bold');text(.05,.55,'Component / total; undefined cells use minimum color','FontSize',12);cb=colorbar(mapAx);cb.Layout.Tile='east';cb.Label.String='Fraction';cb.Ticks=0:0.2:1;
outputs.fractions=fullfile(output_dir,sprintf('CCN_V2_%s_component_fractions_ccn025.png',product_tag));exportgraphics(f,outputs.fractions,'Resolution',250);close(f);
zcount=squeeze(sum(sum(S.sample_count,1),2));zsum=squeeze(sum(sum(S.sum_total(:,:,:,2),1),2));zmean=zsum./zcount;zcomp=squeeze(sum(sum(S.sum_component(:,:,:, :,2),1),2));zcomp=reshape(zcomp,133,5)./zcount;
zaxis=(1:133)';ylabel_text='Canonical CALIPSO vertical-level index';
if isfield(S.meta,'altitude_km')&&numel(S.meta.altitude_km)==133,zaxis=S.meta.altitude_km(:);ylabel_text='Altitude (km)';end
f=figure('Visible','off','Color','w','Position',[50 50 900 600]);plot(zmean,zaxis,'k-','LineWidth',2);hold on;plot(zcomp,zaxis,'LineWidth',1.2);grid on;xlabel('CCN (cm^{-3})');ylabel(ylabel_text);title(sprintf('%s global vertical pooled conditional mean, CCN 0.25%%',month_label));legend(['Total',names],'Location','best');
outputs.vertical=fullfile(output_dir,sprintf('CCN_V2_%s_vertical_profile_ccn025.png',product_tag));
if ~isfile(outputs.vertical),exportgraphics(f,outputs.vertical,'Resolution',250);end
close(f);
T=table(zaxis,zcount(:),zmean(:),zcomp(:,1),zcomp(:,2),zcomp(:,3),zcomp(:,4),zcomp(:,5),'VariableNames',{'canonical_vertical_coordinate','sample_count','total_ccn025','marine','dust','polluted_continental','clean_continental','elevated_smoke'});
outputs.profile_csv=fullfile(output_dir,sprintf('CCN_V2_%s_vertical_profile_ccn025.csv',product_tag));
if ~isfile(outputs.profile_csv),writetable(T,outputs.profile_csv);end
end
function Z=to_log_map(D,limits)
D(D<=0)=NaN;Z=log10(D);finite=isfinite(Z);Z(finite)=max(limits(1),min(limits(2),Z(finite)));Z(~finite)=limits(1);
end
