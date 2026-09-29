function report=check_aod_apro_samples(A,P,geom,cfg)
% Independent scalar arithmetic on a few native profiles, no second producer.
eligible=find(P.valid_for_grid);
chosen=eligible(1:min(2,numel(eligible)));
for t=[5 7]
    j=find(P.valid_for_grid&P.aod_direct(:,t)>0,1); chosen=unique([chosen;j]);
end
j=find(P.valid_for_grid&P.aerosol_subbin_count==0,1); chosen=unique([chosen;j]);
report=zeros(numel(chosen),3);
for r=1:numel(chosen)
    p=chosen(r); d=zeros(1,7); recon=zeros(1,7);
    for k=1:numel(geom.height_km)
        for q=1:2
            f=uint16(A.Atmospheric_Volume_Description(p,k,q));
            if bitand(f,7)~=3,continue;end
            t=double(bitand(bitshift(f,-9),7)); alpha=double(A.Extinction_Coefficient_532(p,k));
            w=geom.bin_thickness_km(k)/2; d(t)=d(t)+alpha*w;
            if t==5||t==7
                beta=double(A.Total_Backscatter_Coefficient_532(p,k)); delta=double(A.Particulate_Depolarization_Ratio_Profile_532(p,k));
                frac=min(1,max(0,(delta-.05)*1.31/(.26*(1+delta))));
                lr=70; if t==7,lr=23;end
                alpha=44*beta*frac+lr*beta*(1-frac);
            end
            recon(t)=recon(t)+alpha*w;
        end
    end
    diff1=max(abs([d,sum(d)]-P.aod_direct(p,:)));
    diff2=max(abs([recon(5),recon(7),sum(recon)]-P.aod_reconstructed_5_7_total(p,:)));
    assert(max(diff1,diff2)<1e-10,'AOD:ManualSample','Independent profile sum differs.');
    report(r,:)=[p,diff1,diff2];
end
fprintf('AOD_MANUAL_PROFILE_PASS samples=%d maxdiff=%g\n',size(report,1),max(report(:,2:3),[],'all'));
end
