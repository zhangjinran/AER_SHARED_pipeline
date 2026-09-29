function number_per_unit_volume = integrate_number_per_unit_volume(component, lower_radius_um, upper_radius_um)
%INTEGRATE_NUMBER_PER_UNIT_VOLUME Integrate normalized bimodal VSD into NSD.

validateattributes(lower_radius_um,{'numeric'},{'scalar','positive'});
validateattributes(upper_radius_um,{'numeric'},{'scalar','positive','>',lower_radius_um});
r=logspace(log10(lower_radius_um),log10(upper_radius_um),200000);
dndlnr=zeros(size(r));
for i=1:2
    v=component.volume_fraction(i); mu=component.mean_radius_um(i); g=component.geometric_std(i);
    dndlnr=dndlnr+(3./(4*pi*r.^3)).* ...
        (v./(sqrt(2*pi)*log(g))).*exp(-0.5*((log(r)-log(mu))./log(g)).^2);
end
number_per_unit_volume=trapz(log(r),dndlnr);
end
