function [angleTable, calibration] = computeAFOJointAngles(bagPath, functionalTimeRange)
% COMPUTEAFOJOINTANGLES  AFO .bag 하나에서 좌우 고관절/무릎/발목 상대각(트라이얼
% 전체, IMU 원 샘플레이트)을 계산한다.
%   /afo_sensor/imu 데이터는 [내부 카운터, IMU_0..IMU_6 각 9개(roll,pitch,yaw,
%   gx,gy,gz,ax,ay,az)] 순서로 들어오므로 1번째 열(카운터)을 떼고 get_IMU_fromBag에
%   넘긴다. IMU_0=골반/몸통, IMU_1=왼허벅지, IMU_2=왼정강이, IMU_3=왼발,
%   IMU_4=오른허벅지, IMU_5=오른정강이, IMU_6=오른발.
%   상대각은 pairs=[0 1;1 2;2 3;0 4;4 5;5 6](왼고관절,왼무릎,왼발목,
%   오른고관절,오른무릎,오른발목)로 계산한다.
%   /afo_gui/kinematics_zero 메시지는 두 개가 오는데, 첫 번째가 global(센서 자체)
%   zeroing 시각, 마지막이 직립 자세(정지 자세) zeroing 시각이다. 센서 프레임
%   정렬(cal_Angle_IMU의 IMU별 쿼터니언 영점)은 첫 번째 시각을, 관절각 자체의
%   영점(직립 자세 기준)은 마지막 시각을 기준으로 맞춘다.
%   functionalTimeRange가 있으면 [시작 끝] absolute epoch초 구간의 보행 상대회전
%   주성분으로 joint별 hinge axis를 추정하고, 해당 축의 quaternion twist만
%   sagittal angle로 쓴다. 없으면 stand zero 이후 전체 bag을 calibration 구간으로
%   사용한다.
%   반환 테이블 컬럼: AFOTime(절대 epoch초), left_hip_angle, left_knee_angle,
%   left_ankle_angle, right_hip_angle, right_knee_angle, right_ankle_angle (모두 deg)

if nargin < 2
    functionalTimeRange = [];
end

pairs = [0 1; 1 2; 2 3; 0 4; 4 5; 5 6];
jointNames = {'left_hip_angle', 'left_knee_angle', 'left_ankle_angle', ...
    'right_hip_angle', 'right_knee_angle', 'right_ankle_angle'};

imuRaw = readAFOBagTopic(bagPath, '/afo_sensor/imu');
imuData.Time = imuRaw.Time;
imuData.Data = imuRaw.Data(:, 2:end);  % 1번째 열은 IMU 보드 내부 카운터라 제외
imuStruct = get_IMU_fromBag(imuData);

zeroRaw = readAFOBagTopic(bagPath, '/afo_gui/kinematics_zero');
if numel(zeroRaw.Time) < 2
    error('computeAFOJointAngles:missingZeroing', ...
        'Global and stand zeroing messages are both required: %s', bagPath);
end
zeroingTimeGlobal = zeroRaw.Time(1);   % 첫번째: global(센서 자체) zeroing -> 센서 프레임 정렬 기준
zeroingTimeStand = zeroRaw.Time(end); % 마지막: 직립 상태 zeroing -> 관절각 영점 기준

[~, ~, qRelative, timeStruct] = cal_Angle_IMU(imuStruct, zeroingTimeGlobal, pairs);

afoTime = imuRaw.Time;  % 모든 IMU가 같은 /afo_sensor/imu 메시지에서 나오므로 시간축 공유
[~, idxZero] = min(abs(afoTime - zeroingTimeStand));

if isempty(functionalTimeRange)
    functionalMask = afoTime >= zeroingTimeStand;
    functionalTimeRange = [zeroingTimeStand, afoTime(end)];
else
    if numel(functionalTimeRange) ~= 2 || functionalTimeRange(1) >= functionalTimeRange(2)
        error('computeAFOJointAngles:invalidFunctionalWindow', ...
            'functionalTimeRange must be [startTime endTime] with startTime < endTime.');
    end
    functionalTimeRange = reshape(functionalTimeRange, 1, 2);
    functionalMask = afoTime >= functionalTimeRange(1) & afoTime <= functionalTimeRange(2);
end

angleCols = zeros(numel(afoTime), numel(jointNames));
calibration = struct();
calibration.method = 'functional_hinge_twist';
calibration.groundTime = zeroingTimeGlobal;
calibration.standTime = zeroingTimeStand;
calibration.functionalStartTime = functionalTimeRange(1);
calibration.functionalEndTime = functionalTimeRange(2);
calibration.joints = struct('name', {}, 'axis', {}, 'sampleCount', {}, ...
    'selectedSampleCount', {}, 'explainedVariance', {}, 'refAlignment', {}, ...
    'p05Deg', {}, 'p95Deg', {});

bagLabel = describeBagPath(bagPath);

for k = 1:size(pairs, 1)
    nameA = sprintf('IMU_%d', pairs(k, 1));
    nameB = sprintf('IMU_%d', pairs(k, 2));
    qJoint = pairRelativeQuaternion(qRelative.(nameA), timeStruct.(nameA), ...
        qRelative.(nameB), timeStruct.(nameB));
    qStand = qJoint(idxZero, :);
    qDelta = leftMultiplyQuaternion(quatinv(qStand), qJoint);

    jointLabel = sprintf('%s %s', bagLabel, jointNames{k});
    [axis, diagnostics] = estimateFunctionalHingeAxis(qDelta, functionalMask, [], jointLabel);
    angle = rad2deg(extractTwistAngle(qDelta, axis));
    angleCols(:, k) = angle - angle(idxZero);  % stand neutral = 0 deg

    calibration.joints(k) = struct( ...
        'name', jointNames{k}, 'axis', axis, ...
        'sampleCount', diagnostics.sampleCount, ...
        'selectedSampleCount', diagnostics.selectedSampleCount, ...
        'explainedVariance', diagnostics.explainedVariance, ...
        'refAlignment', diagnostics.refAlignment, ...
        'p05Deg', diagnostics.p05Deg, 'p95Deg', diagnostics.p95Deg);
end

angleTable = array2table([afoTime, angleCols], 'VariableNames', [{'AFOTime'}, jointNames]);
angleTable.Properties.UserData = calibration;
end

function label = describeBagPath(bagPath)
% bagPath에서 subject/date/bag파일명만 뽑아 경고 메시지용 짧은 식별자를 만든다.
% 중간 폴더 depth(예: <subject>/<date>/AFO/file.bag 또는
% <subject>/<date>/raw/AFO/file.bag)에 상관없이, 경로에서 YYMMDD 형식(6자리 숫자)
% 폴더명을 날짜로 찾고 그 바로 위 폴더를 subject로 삼는다.
% 예: '.../SAH04/260728/raw/AFO/p1.bag' -> 'SAH04/260728/p1.bag'
parts = strsplit(strrep(bagPath, '\', '/'), '/');
isDateLike = ~cellfun(@isempty, regexp(parts, '^\d{6}$', 'once'));
dateIdx = find(isDateLike, 1, 'last');

[~, bagName, bagExt] = fileparts(bagPath);
if isempty(dateIdx) || dateIdx < 2
    label = [bagName, bagExt];
else
    label = sprintf('%s/%s/%s%s', parts{dateIdx - 1}, parts{dateIdx}, bagName, bagExt);
end
end

function qJoint = pairRelativeQuaternion(qA, tA, qB, tB)
idxB = interp1(tB, 1:numel(tB), tA, 'nearest', 'extrap');
qJoint = zeros(numel(tA), 4);
for i = 1:numel(tA)
    qJoint(i, :) = quatmultiply(quatinv(qA(i, :)), qB(idxB(i), :));
end
qJoint = quatnormalize(qJoint);
end

function qOut = leftMultiplyQuaternion(qLeft, qRight)
qOut = zeros(size(qRight));
for i = 1:size(qRight, 1)
    qOut(i, :) = quatmultiply(qLeft, qRight(i, :));
end
qOut = quatnormalize(qOut);
end
