function Data=Fun_CALIPSO_Calculation_dVdlnr_dNdlnr_Nd_Consider_Hyg_Integral(Data_CALIPSO,Radius,Para_Particle,Extinction_Normalized_All,rmin_target,rmax_target)
%% 计算dVdlnr,dNdlnr,Nd (★ 引入 ERA5 真实湿度 & 修复吸湿增长公式)
%%输入参数与之前相同，但 Data_CALIPSO 结构体中必须包含 Out_RH 字段

    Data = [];  
    
    %% 粒径谱分布参数
    VolumeFraction_fineMode=Para_Particle.v_i_fine;
    MedianRadius_fineMode=Para_Particle.r_mean_fine;
    GeometricStdDev_fineMode=Para_Particle.GSD_fine;
    VolumeFraction_coarseMode=Para_Particle.v_i_coarse;
    MedianRadius_coarseMode=Para_Particle.r_mean_coarse;
    GeometricStdDev_coarseMode=Para_Particle.GSD_coarse;
    
    Out_Type_Aer=Data_CALIPSO.Out_Type_Aer2;
    ExtCoef_Particle_CALIPSO=Data_CALIPSO.Out_ExtCoef_Particle;
    Depolarization_Ratio_CALIPSO=Data_CALIPSO.Out_Depolarization_Ratio;
    Backscatter_Coefficient_CALIPSO=Data_CALIPSO.Out_Backscatter_Coefficient;
    
    % ★ 核心修改 1：提取传入的真实湿度数据
    if isfield(Data_CALIPSO, 'Out_RH')
        RH_CALIPSO = Data_CALIPSO.Out_RH;
    else
        error('Data_CALIPSO 缺少 Out_RH 字段！请确保传入了湿度数据。');
    end
    
    % ★ 核心修改 2：强制统一湿度单位为 0-1 的小数，防止报错
    if nanmean(RH_CALIPSO(:)) > 1
        RH_CALIPSO = RH_CALIPSO / 100.0; 
    end

    Index_valid=~isnan(ExtCoef_Particle_CALIPSO)&~isnan(Depolarization_Ratio_CALIPSO)&~isnan(Backscatter_Coefficient_CALIPSO)...
    &(ExtCoef_Particle_CALIPSO>0)&(Depolarization_Ratio_CALIPSO>0) &Depolarization_Ratio_CALIPSO<0.31&Depolarization_Ratio_CALIPSO>0.05;

    if(nansum(Index_valid(:))~=0)
        ExtCoef_Particle_CALIPSO_valid=nan*ones(size(ExtCoef_Particle_CALIPSO));
        Depolarization_Ratio_CALIPSO_valid=nan*ones(size(ExtCoef_Particle_CALIPSO));
        Backscatter_Coefficient_CALIPSO_valid=nan*ones(size(ExtCoef_Particle_CALIPSO));
        RH_CALIPSO_valid=nan*ones(size(ExtCoef_Particle_CALIPSO));
        Out_Type_All_valid=nan*ones(size(ExtCoef_Particle_CALIPSO));
        Out_Type_Aer_valid=nan*ones(size(ExtCoef_Particle_CALIPSO));
        Parameter_dust=nan*ones(size(ExtCoef_Particle_CALIPSO));
        Vt=nan*ones(size(ExtCoef_Particle_CALIPSO));
        Vt_ND=nan*ones(size(ExtCoef_Particle_CALIPSO));
        MedianRadius_fineMode_All_dry=nan*ones(size(ExtCoef_Particle_CALIPSO));
        MedianRadius_coarseMode_All_dry=nan*ones(size(ExtCoef_Particle_CALIPSO));
        VolumeFraction_fineMode_All=nan*ones(size(ExtCoef_Particle_CALIPSO));
        VolumeFraction_coarseMode_All=nan*ones(size(ExtCoef_Particle_CALIPSO));
        GeometricStdDev_fineMode_All=nan*ones(size(ExtCoef_Particle_CALIPSO));
        GeometricStdDev_coarseMode_All=nan*ones(size(ExtCoef_Particle_CALIPSO));
        
        ExtCoef_Particle_CALIPSO_valid(Index_valid)=ExtCoef_Particle_CALIPSO(Index_valid);
        Depolarization_Ratio_CALIPSO_valid(Index_valid)=Depolarization_Ratio_CALIPSO(Index_valid);
        Backscatter_Coefficient_CALIPSO_valid(Index_valid)=Backscatter_Coefficient_CALIPSO(Index_valid);
        RH_CALIPSO_valid(Index_valid)=RH_CALIPSO(Index_valid);
        
        % 计算查表索引 (RH 是 0-1 的小数)
        Index_RH_Normalized=round(RH_CALIPSO_valid*100)+1;
        Index_RH_Normalized(Index_RH_Normalized>100)=100;
        Out_Type_Aer_valid(Index_valid)=Out_Type_Aer(Index_valid);
        
        Index_Continental=Out_Type_Aer_valid>1&Out_Type_Aer_valid<7;
        Index_Marine=Out_Type_Aer_valid==1|Out_Type_Aer_valid==7;
        Kappa=zeros(size(Index_Continental));
        Kappa(Index_Continental)=0.3;
        Kappa(Index_Marine)=0.7;
        
        Index_RH_Normalized(isnan(Index_RH_Normalized))=1;
        Index_RH_Normalized(~isnan(Index_RH_Normalized))=1;
        Out_Type_Aer_valid(Out_Type_Aer_valid>7)=nan;
        
        for Type_i=1:7
            type_temp=Type_i;
            Index_temp=Out_Type_Aer_valid==Type_i;
            if(sum(Index_temp(:))>0)
                if(Type_i==2)
                    Out_Type_Aer_valid_DU=Type_i*ones(size(Out_Type_Aer_valid));
                    Extinction_Normalized_All_valid_temp=Extinction_Normalized_All(sub2ind(size(Extinction_Normalized_All),Out_Type_Aer_valid_DU,Index_RH_Normalized));
                    temp=ExtCoef_Particle_CALIPSO_valid./Extinction_Normalized_All_valid_temp.*10^9;
                    Vt(Index_temp)=temp(Index_temp);
                    Vt_ND(Index_temp)=0;
                else
                    if(Type_i==5||Type_i==7)
                        Out_Type_Aer_valid_DU=2*ones(size(Out_Type_Aer_valid));
                        Extinction_Normalized_All_valid_DU=Extinction_Normalized_All(sub2ind(size(Extinction_Normalized_All),Out_Type_Aer_valid_DU,Index_RH_Normalized));
                        if(Type_i==5)
                            Out_Type_Aer_valid_ND=3*ones(size(Out_Type_Aer_valid));
                            type_temp=3;
                        else
                            Out_Type_Aer_valid_ND=1*ones(size(Out_Type_Aer_valid));
                            type_temp=1;
                        end
                        Extinction_Normalized_All_valid_ND=Extinction_Normalized_All(sub2ind(size(Extinction_Normalized_All),Out_Type_Aer_valid_ND,Index_RH_Normalized));
                        Parameter_dust(Index_temp)=(Depolarization_Ratio_CALIPSO_valid(Index_temp)-0.05)*1.31/0.26./(1+Depolarization_Ratio_CALIPSO_valid(Index_temp));
                        if(type_temp==3)
                            temp=70*Backscatter_Coefficient_CALIPSO_valid.*(1-Parameter_dust)./Extinction_Normalized_All_valid_ND.*10^9;
                            Vt_ND(Index_temp)=temp(Index_temp);
                        else
                            temp=23*Backscatter_Coefficient_CALIPSO_valid.*(1-Parameter_dust)./Extinction_Normalized_All_valid_ND.*10^9;
                            Vt_ND(Index_temp)=temp(Index_temp);
                        end
                        temp=44*Backscatter_Coefficient_CALIPSO_valid.*Parameter_dust./Extinction_Normalized_All_valid_DU.*10^9;
                        Vt(Index_temp)=temp(Index_temp);
                    else
                        Out_Type_Aer_valid_Other=Out_Type_Aer_valid;
                        Out_Type_Aer_valid_Other(Out_Type_Aer_valid==5|Out_Type_Aer_valid==7|isnan(Out_Type_Aer_valid))=1;
                        Out_Type_Aer_valid_Other(Out_Type_Aer_valid_Other==0)=1;
                        Extinction_Normalized_All_valid_other=Extinction_Normalized_All(sub2ind(size(Extinction_Normalized_All),Out_Type_Aer_valid_Other,Index_RH_Normalized));
                        temp=ExtCoef_Particle_CALIPSO_valid./Extinction_Normalized_All_valid_other.*10^9;
                        Vt(Index_temp)=0;
                        Vt_ND(Index_temp)=temp(Index_temp);
                    end
                end
                MedianRadius_fineMode_All_dry(Index_temp)=MedianRadius_fineMode(type_temp);
                MedianRadius_coarseMode_All_dry(Index_temp)=MedianRadius_coarseMode(type_temp);
                VolumeFraction_fineMode_All(Index_temp)=VolumeFraction_fineMode(type_temp);
                VolumeFraction_coarseMode_All(Index_temp)=VolumeFraction_coarseMode(type_temp);
                GeometricStdDev_fineMode_All(Index_temp)=GeometricStdDev_fineMode(type_temp);
                GeometricStdDev_coarseMode_All(Index_temp)=GeometricStdDev_coarseMode(type_temp);         
            end
        end
        
        % ★ 核心修改 3：修复 Kappa 吸湿增长公式的物理单位 Bug
        % RH_CALIPSO_valid 已经是 0-1 的小数，分母必须是 (1 - RH_CALIPSO_valid)
        f_RH=(1 + Kappa .* RH_CALIPSO_valid ./ (1 - RH_CALIPSO_valid)).^(1/3);
        
        % 为了防止极端高湿导致粒子无限膨胀，加一个物理保护上限 (比如RH=99%时)
        f_RH(f_RH > 10) = 10; 
        
        MedianRadius_fineMode_All_wet=MedianRadius_fineMode_All_dry.*f_RH;
        MedianRadius_coarseMode_All_wet=MedianRadius_coarseMode_All_dry.*f_RH;
        
        temp=reshape(Radius,1,1,length(Radius));
        Radius2=repmat(temp,size(f_RH,1),size(f_RH,2),1);
        
        % 后面的谱分布计算公式保持原样...
        dVdlnr_DU_fine_dry=VolumeFraction_fineMode(2)./(sqrt(2*pi).*log(GeometricStdDev_fineMode(2))).*exp(-(log(Radius2)-log(MedianRadius_fineMode(2))).^2./(2.*(log(GeometricStdDev_fineMode(2))).^2));
        dVdlnr_DU_coarse_dry=VolumeFraction_coarseMode(2)./(sqrt(2*pi).*log(GeometricStdDev_coarseMode(2))).*exp(-(log(Radius2)-log(MedianRadius_coarseMode(2))).^2./(2.*(log(GeometricStdDev_coarseMode(2))).^2));
        dVdlnr_DU_fine_wet=VolumeFraction_fineMode(2)./(sqrt(2*pi).*log(GeometricStdDev_fineMode(2))).*exp(-(log(Radius2)-log(MedianRadius_fineMode(2))).^2./(2.*(log(GeometricStdDev_fineMode(2))).^2));
        dVdlnr_DU_coarse_wet=VolumeFraction_coarseMode(2)./(sqrt(2*pi).*log(GeometricStdDev_coarseMode(2))).*exp(-(log(Radius2)-log(MedianRadius_coarseMode(2))).^2./(2.*(log(GeometricStdDev_coarseMode(2))).^2));
        
        dVdlnr_ND_fine_dry=VolumeFraction_fineMode_All./(sqrt(2*pi).*log(GeometricStdDev_fineMode_All)).*exp(-(log(Radius2)-log(MedianRadius_fineMode_All_dry)).^2./(2.*(log(GeometricStdDev_fineMode_All)).^2));
        dVdlnr_ND_coarse_dry=VolumeFraction_coarseMode_All./(sqrt(2*pi).*log(GeometricStdDev_coarseMode_All)).*exp(-(log(Radius2)-log(MedianRadius_coarseMode_All_dry)).^2./(2.*(log(GeometricStdDev_coarseMode_All)).^2));
        dVdlnr_ND_fine_wet=VolumeFraction_fineMode_All./(sqrt(2*pi).*log(GeometricStdDev_fineMode_All)).*exp(-(log(Radius2)-log(MedianRadius_fineMode_All_wet)).^2./(2.*(log(GeometricStdDev_fineMode_All)).^2));
        dVdlnr_ND_coarse_wet=VolumeFraction_coarseMode_All./(sqrt(2*pi).*log(GeometricStdDev_coarseMode_All)).*exp(-(log(Radius2)-log(MedianRadius_coarseMode_All_wet)).^2./(2.*(log(GeometricStdDev_coarseMode_All)).^2));
        
        dVdlnr_dry_CALIPSO=Vt.*(dVdlnr_DU_fine_dry+dVdlnr_DU_coarse_dry)+Vt_ND.*(dVdlnr_ND_fine_dry+dVdlnr_ND_coarse_dry);
        dNdlnr_dry_CALIPSO=3./(4.*pi.*Radius2.^3).*dVdlnr_dry_CALIPSO;
        
        dVdlnr_wet_CALIPSO=Vt.*(dVdlnr_DU_fine_wet+dVdlnr_DU_coarse_wet)+Vt_ND.*(dVdlnr_ND_fine_wet+dVdlnr_ND_coarse_wet);
        dNdlnr_wet_CALIPSO=3./(4.*pi.*Radius2.^3).*dVdlnr_wet_CALIPSO;
        
        %% 计算Nd
        [Ind_row,Ind_col]=find(~isnan(Vt));
        Nd_DU_dry_CALIPSO=nan*ones(size(Vt)); Nd_ND_dry_CALIPSO=nan*ones(size(Vt));
        Nd_DU_wet_CALIPSO=nan*ones(size(Vt)); Nd_ND_wet_CALIPSO=nan*ones(size(Vt));
        Nd_DU_dry_CALIPSO_target=nan*ones(size(Vt)); Nd_ND_dry_CALIPSO_target=nan*ones(size(Vt));
        Nd_DU_wet_CALIPSO_target=nan*ones(size(Vt)); Nd_ND_wet_CALIPSO_target=nan*ones(size(Vt));
        CCN_DU=nan*ones(size(Vt));CCN_ND=nan*ones(size(Vt));%补充CCN

        
        for data_i=1:length(Ind_row)
            dVdlnr_DU_fine_dry_f=@(r) VolumeFraction_fineMode(2)./(sqrt(2*pi).*log(GeometricStdDev_fineMode(2))).*exp(-(log(r)-log(MedianRadius_fineMode(2))).^2./(2.*(log(GeometricStdDev_fineMode(2))).^2));
            dVdlnr_DU_coarse_dry_f=@(r) VolumeFraction_coarseMode(2)./(sqrt(2*pi).*log(GeometricStdDev_coarseMode(2))).*exp(-(log(r)-log(MedianRadius_coarseMode(2))).^2./(2.*(log(GeometricStdDev_coarseMode(2))).^2));
            dVdlnr_DU_dry_f=@(r) Vt(Ind_row(data_i),Ind_col(data_i)).*(dVdlnr_DU_fine_dry_f(r)+dVdlnr_DU_coarse_dry_f(r));
            dNdr_DU_dry_f=@(r) 1./r.*3./(4.*pi.*r.^3).*dVdlnr_DU_dry_f(r);
            Nd_DU_dry_CALIPSO(Ind_row(data_i),Ind_col(data_i))=integral(@(r) dNdr_DU_dry_f(r),0.1,15);
            
            dVdlnr_DU_fine_wet_f=@(r) VolumeFraction_fineMode(2)./(sqrt(2*pi).*log(GeometricStdDev_fineMode(2))).*exp(-(log(r)-log(MedianRadius_fineMode(2))).^2./(2.*(log(GeometricStdDev_fineMode(2))).^2));
            dVdlnr_DU_coarse_wet_f=@(r) VolumeFraction_coarseMode(2)./(sqrt(2*pi).*log(GeometricStdDev_coarseMode(2))).*exp(-(log(r)-log(MedianRadius_coarseMode(2))).^2./(2.*(log(GeometricStdDev_coarseMode(2))).^2));
            dVdlnr_DU_wet_f=@(r) Vt(Ind_row(data_i),Ind_col(data_i)).*(dVdlnr_DU_fine_wet_f(r)+dVdlnr_DU_coarse_wet_f(r));
            dNdr_DU_wet_f=@(r) 1./r.*3./(4.*pi.*r.^3).*dVdlnr_DU_wet_f(r);
            Nd_DU_wet_CALIPSO(Ind_row(data_i),Ind_col(data_i))=integral(@(r) dNdr_DU_wet_f(r),0.1,15);
            
            dVdlnr_ND_fine_dry_f=@(r) VolumeFraction_fineMode_All(Ind_row(data_i),Ind_col(data_i))./(sqrt(2*pi).*log(GeometricStdDev_fineMode_All(Ind_row(data_i),Ind_col(data_i)))).*exp(-(log(r)-log(MedianRadius_fineMode_All_dry(Ind_row(data_i),Ind_col(data_i)))).^2./(2.*(log(GeometricStdDev_fineMode_All(Ind_row(data_i),Ind_col(data_i)))).^2));
            dVdlnr_ND_coarse_dry_f=@(r) VolumeFraction_coarseMode_All(Ind_row(data_i),Ind_col(data_i))./(sqrt(2*pi).*log(GeometricStdDev_coarseMode_All(Ind_row(data_i),Ind_col(data_i)))).*exp(-(log(r)-log(MedianRadius_coarseMode_All_dry(Ind_row(data_i),Ind_col(data_i)))).^2./(2.*(log(GeometricStdDev_coarseMode_All(Ind_row(data_i),Ind_col(data_i)))).^2));
            dVdlnr_ND_dry_f=@(r) Vt_ND(Ind_row(data_i),Ind_col(data_i)).*(dVdlnr_ND_fine_dry_f(r)+dVdlnr_ND_coarse_dry_f(r));
            dNdr_ND_dry_f=@(r) 1./r.*3./(4.*pi.*r.^3).*dVdlnr_ND_dry_f(r);
            Nd_ND_dry_CALIPSO(Ind_row(data_i),Ind_col(data_i))=integral(@(r) dNdr_ND_dry_f(r),0.05,15);
            
            dVdlnr_ND_fine_wet_f=@(r) VolumeFraction_fineMode_All(Ind_row(data_i),Ind_col(data_i))./(sqrt(2*pi).*log(GeometricStdDev_fineMode_All(Ind_row(data_i),Ind_col(data_i)))).*exp(-(log(r)-log(MedianRadius_fineMode_All_wet(Ind_row(data_i),Ind_col(data_i)))).^2./(2.*(log(GeometricStdDev_fineMode_All(Ind_row(data_i),Ind_col(data_i)))).^2));
            dVdlnr_ND_coarse_wet_f=@(r) VolumeFraction_coarseMode_All(Ind_row(data_i),Ind_col(data_i))./(sqrt(2*pi).*log(GeometricStdDev_coarseMode_All(Ind_row(data_i),Ind_col(data_i)))).*exp(-(log(r)-log(MedianRadius_coarseMode_All_wet(Ind_row(data_i),Ind_col(data_i)))).^2./(2.*(log(GeometricStdDev_coarseMode_All(Ind_row(data_i),Ind_col(data_i)))).^2));
            dVdlnr_ND_wet_f=@(r) Vt_ND(Ind_row(data_i),Ind_col(data_i)).*(dVdlnr_ND_fine_wet_f(r)+dVdlnr_ND_coarse_wet_f(r));
            dNdr_ND_wet_f=@(r) 1./r.*3./(4.*pi.*r.^3).*dVdlnr_ND_wet_f(r);
            Nd_ND_wet_CALIPSO(Ind_row(data_i),Ind_col(data_i))=integral(@(r) dNdr_ND_wet_f(r),0.05,15);
            

            if(~isempty(rmin_target))
                n_r = @(r) (1 ./ (r .* log(delta) .* sqrt(2 * pi ))) .* exp(-(log(r) - log(rm)).^2 ./ (2 * log(delta).^2)); 
                Nd_DU_dry_CALIPSO_target(Ind_row(data_i),Ind_col(data_i))=Nd_DU_dry_CALIPSO(Ind_row(data_i),Ind_col(data_i)).*integral(n_r,rmin_target,rmax_target);
                Nd_DU_wet_CALIPSO_target(Ind_row(data_i),Ind_col(data_i))=Nd_DU_wet_CALIPSO(Ind_row(data_i),Ind_col(data_i)).*integral(n_r,rmin_target,rmax_target);
                Nd_ND_dry_CALIPSO_target(Ind_row(data_i),Ind_col(data_i))=Nd_ND_dry_CALIPSO(Ind_row(data_i),Ind_col(data_i)).*integral(n_r,rmin_target,rmax_target);
                Nd_ND_wet_CALIPSO_target(Ind_row(data_i),Ind_col(data_i))=Nd_ND_wet_CALIPSO(Ind_row(data_i),Ind_col(data_i)).*integral(n_r,rmin_target,rmax_target);
                %% 补充CCN计算
                T=Data_CALIPSO.Temp;
                r_crit=Fun_Calculate_rcrit(T,kappa,RH_CALIPSO_valid*100);%计算截断半径
                dn_dlnr = @(r) (1 ./ (log(delta) .* sqrt(2 * pi ))) .* exp(-(log(r) - log(rm)).^2 ./ (2 * log(delta).^2)); 
                CCN_DU(Ind_row(data_i),Ind_col(data_i))=Nd_DU_wet_CALIPSO(Ind_row(data_i),Ind_col(data_i)).*integral(dn_dlnr,log(r_crit),log(rmax_target));
                CCN_ND(Ind_row(data_i),Ind_col(data_i))=Nd_ND_wet_CALIPSO(Ind_row(data_i),Ind_col(data_i)).*integral(dn_dlnr,log(r_crit),log(rmax_target));
                
            end
        end
        
        Nd_dry_CALIPSO=Nd_DU_dry_CALIPSO+Nd_ND_dry_CALIPSO;
        Nd_wet_CALIPSO=Nd_DU_wet_CALIPSO+Nd_ND_wet_CALIPSO;
        Nd_dry_CALIPSO_target=Nd_DU_dry_CALIPSO_target+Nd_ND_dry_CALIPSO_target;
        Nd_wet_CALIPSO_target=Nd_DU_wet_CALIPSO_target+Nd_ND_wet_CALIPSO_target;
        %% 补充CCN计算
        CCN_crit=CCN_DU+CCN_ND;%使用截断半径计算的结果,参考Patel et al.,ACP,2022
        CCN_15=1.0*Nd_dry_CALIPSO;%%CCN=fss*Nd_dry,SS:0.15%,fss=1.0,参考M.Tesche，et al.,AMT，2022
        CCN_25=1.35*Nd_dry_CALIPSO;%%CCN=fss*Nd_dry,SS:0.25%,fss=1.35
        CCN_40=1.70*Nd_dry_CALIPSO;%%CCN=fss*Nd_dry,SS:0.40%,fss=1.7

        
        Data.Radius=Radius;
        Data.Type_All=Out_Type_All_valid;
        Data.Type_Aer=Out_Type_Aer_valid;
        Data.f_RH=f_RH;
        Data.RH=RH_CALIPSO_valid;
        Data.dVdlnr_wet_CALIPSO=dVdlnr_wet_CALIPSO;
        Data.dVdlnr_dry_CALIPSO=dVdlnr_dry_CALIPSO;
        Data.dNdlnr_wet=dNdlnr_wet_CALIPSO;
        Data.dNdlnr_dry=dNdlnr_dry_CALIPSO;
        Data.Nd_CALIPSO_wet=Nd_wet_CALIPSO;
        Data.Nd_CALIPSO_dry=Nd_dry_CALIPSO;
        Data.Nd_wet_CALIPSO_target=Nd_wet_CALIPSO_target;
        Data.Nd_dry_CALIPSO_target=Nd_dry_CALIPSO_target;
        Data.ExtCoef_Particle_CALIPSO_valid=ExtCoef_Particle_CALIPSO_valid;
        Data.Depolarization_Ratio_CALIPSO_valid=Depolarization_Ratio_CALIPSO_valid;
        Data.Backscatter_Coefficient_CALIPSO_valid=Backscatter_Coefficient_CALIPSO_valid;
        Data.RH_CALIPSO_valid=RH_CALIPSO_valid;
        Data.CCN_crit=CCN_crit;%补充CCN的结果
        Data.CCN_15=CCN_15;%补充CCN的结果,单位：1/cm^3
        Data.CCN_25=CCN_25;%补充CCN的结果
        Data.CCN_40=CCN_40;%补充CCN的结果
    end
end