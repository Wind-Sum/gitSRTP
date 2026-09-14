function measurements = load_experiment_measurements(resultsRoot, cfg)
%LOAD_EXPERIMENT_MEASUREMENTS 严格读取 Location1--4 的三种原始采集。

measurements = repmat(struct(),4,1);
for locationIndex = 1:4
    locationRoot = fullfile(resultsRoot,cfg.locationNames{locationIndex});
    revFile = find_result(locationRoot,'REV_*','REV_Localization_Result.mat');
    onOffFile = find_result(locationRoot,'OnOff_*','OnOff_Localization_Result.mat');
    hadFile = find_result(locationRoot,'Hadamard_*','Hadamard_Localization_Result.mat');
    rev = load_result(revFile);
    onoff = load_result(onOffFile);
    had = load_result(hadFile);
    assert_axis(rev.frequencyHz,onoff.frequencyHz,'On/Off',cfg.locationNames{locationIndex});
    assert_axis(rev.frequencyHz,had.frequencyHz,'Hadamard',cfg.locationNames{locationIndex});
    required(rev,'ZRev',revFile); required(onoff,'HDirect',onOffFile);
    required(had,'YPattern',hadFile); required(had,'codebook',hadFile);
    measurements(locationIndex).location = cfg.locationNames{locationIndex};
    measurements(locationIndex).frequencyHz = rev.frequencyHz(:);
    measurements(locationIndex).rev = rev;
    measurements(locationIndex).onoff = onoff;
    measurements(locationIndex).hadamard = had;
    measurements(locationIndex).files = struct('rev',revFile,'onoff',onOffFile,'hadamard',hadFile);
end
end

function file = find_result(root,folderPattern,fileName)
listing = dir(fullfile(root,folderPattern,fileName));
if isempty(listing)
    error('FourBranchRev:MissingResult','未找到 %s。',fullfile(root,folderPattern,fileName));
end
[~,order] = sort([listing.datenum],'descend'); listing = listing(order);
if numel(listing)>1
    warning('FourBranchRev:MultipleResults','%s 有多个结果，使用最新文件。',root);
end
file = fullfile(listing(1).folder,listing(1).name);
end

function result = load_result(file)
s = load(file,'result');
if ~isfield(s,'result') || ~isstruct(s.result)
    error('FourBranchRev:InvalidResult','%s 缺少 result 结构体。',file);
end
result = s.result;
end

function required(s,field,file)
if ~isfield(s,field)
    error('FourBranchRev:MissingCanonicalField','%s 缺少 %s；不回退到 HChannel。',file,field);
end
end

function assert_axis(a,b,method,location)
if ~isequal(size(a),size(b)) || any(abs(a(:)-b(:))>1)
    error('FourBranchRev:FrequencyMismatch','%s 的 %s 频率轴不一致。',location,method);
end
end
