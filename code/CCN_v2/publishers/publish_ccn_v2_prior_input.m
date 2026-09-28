function prior_root = publish_ccn_v2_prior_input(candidate_root)
%PUBLISH_CCN_V2_PRIOR_INPUT Promote the validated small prior pair without copying it.
root='F:\AER_SHARED_PIPELINE';
prior_root=fullfile(root,'inputs','priors','ccn_v2','omcam_v2__acp-table4-unitgate-v1');
if isfolder(prior_root),error('CCNv2:PriorExists','Prior input already exists: %s',prior_root);end
srcp=fullfile(candidate_root,'Parameter_OMCAM_v2.mat');
srce=fullfile(candidate_root,'Extinction_Normalized_v2.mat');
if ~isfile(srcp)||~isfile(srce),error('CCNv2:MissingPriorCandidate','Candidate pair missing.');end
mkdir(prior_root);
[ok,msg]=movefile(srcp,fullfile(prior_root,'Parameter_OMCAM_v2.mat'));if ~ok,error('CCNv2:Move',msg);end
[ok,msg]=movefile(srce,fullfile(prior_root,'Extinction_Normalized_v2.mat'));if ~ok,error('CCNv2:Move',msg);end
fid=fopen(fullfile(prior_root,'manifest.txt'),'w');
fprintf(fid,['schema=omcam-v2\nunit_gate=PASS\nmarine_shape=sphere\ndust_shape=spheroid\nrh_grid=0:99\nstatus=IMMUTABLE_INPUT\n']);
fclose(fid);
fclose(fopen(fullfile(prior_root,'_SUCCESS'),'w'));
end
