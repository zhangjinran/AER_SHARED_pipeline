%% 截断半径计算公式
%% 输入：T,绝对温度,kappa：吸湿增长系数，RH:相对湿度%
function r_crit=Fun_Calculate_rcrit(T,kappa,RH)
Mw=0.018;% kg mol⁻¹
pw=1000;% kg⋅m −3
delta_s_a=0.072;%J/m2;
R=8.314;% J/(mol·K);理想气体常量
A=4*delta_s_a.*Mw./(R.*T.*pw);
RH(RH<=100)=nan;
SS=RH/100-1;
Sc= SS+1;
D_crit=(4*A^3./(27*kappa*log(Sc).^2)).^(1/3);
r_crit=D_crit./2*10^6;%米转微米

end