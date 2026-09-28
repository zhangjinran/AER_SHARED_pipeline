function v = product_versions()
%PRODUCT_VERSIONS Version boundaries for shared derived products.
%
% Changing any version below creates a new product identity.
% Existing successful products must never be overwritten.

%% Canonical logical input version
v.AP_VERSION = 'ap-final-v1';

%% T_all processing contract
v.TALL_ADAPTER_VERSION = 'adapter-v1';
v.TALL_QC_VERSION = 'qc-v1';

%% CALIPSO_STATS processing contract
v.STATS_VERSION = 'stats-v1';

%% Manifest/schema contract
v.MANIFEST_VERSION = 'manifest-v1';
v.PRODUCT_SCHEMA_VERSION = 'product-schema-v1';

%% Current sharing status
v.TALL_SHARE_STATUS = 'shared_derived_frozen';
v.STATS_SHARE_STATUS = 'candidate_shared_until_gate_d';

%% Product immutability
v.IMMUTABLE_AFTER_SUCCESS = true;

end
