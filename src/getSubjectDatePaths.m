function paths = getSubjectDatePaths(rootDir, subject, dateStr)
% GETSUBJECTDATEPATHS  표준 subject/date 데이터 구조의 경로를 반환한다.
%   <root>/<subject>/sync_data/
%   <root>/<subject>/<date>/raw/{emg,afo,mw,video}/
%   <root>/<subject>/<date>/processed/{emg_steps,emg_afo_steps}/

baseDir = fullfile(rootDir, subject, dateStr);

paths.baseDir = baseDir;
paths.syncDir = fullfile(rootDir, subject, 'sync_data');
paths.emgRawDir = fullfile(baseDir, 'raw', 'emg');
paths.afoRawDir = fullfile(baseDir, 'raw', 'afo');
paths.mwRawDir = fullfile(baseDir, 'raw', 'mw');
paths.videoRawDir = fullfile(baseDir, 'raw', 'video');
paths.emgStepsDir = fullfile(baseDir, 'processed', 'emg_steps');
paths.emgAfoStepsDir = fullfile(baseDir, 'processed', 'emg_afo_steps');
end
