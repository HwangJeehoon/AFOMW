function [angleTable, calibration] = computeAFOJointAnglesSagittal(bagPath, functionalTimeRange)
% COMPUTEAFOJOINTANGLESSAGITTAL  computeAFOJointAngles의 실험용 대안 알고리즘.
%
%   가정(고정, 데이터로 추정하지 않음):
%     - 각 IMU 로컬 Y축("pitch"가 도는 축) = 그 segment의 뼈 장축(limb direction)
%     - 각 IMU 로컬 X축("roll"이 도는 축)  = mediolateral(내외측) 방향
%   두 가정이 맞다면, local Y-Z 평면(=roll축과 normal한 평면)이 곧 sagittal
%   plane이 되고, 그 평면에 투영한 각도가 sagittal(굴곡-신전) 각도가 된다.
%
%   계산 순서:
%     1) qJoint(t) = quatinv(qA(t)) ⊗ qB(t)  - computeAFOJointAngles와 동일하게
%        A/B 각자의 (서로 무관하게 임의로 정해지는) global-zero 기준을 상쇄해
%        "A 좌표계에서 본 B의 상대회전"이라는 하나의 일관된 좌표계로 만든다.
%        (v1에서는 이 단계를 생략하고 vA, vB를 각자 좌표계에서 따로 구해
%        바로 cross해서 좌표계가 안 맞는 채로 계산되는 버그가 있었다.)
%     2) vRel(t) = qJoint(t)로 로컬 Y축[0 1 0]을 회전 → A가 보는 B의 limb 방향.
%        정지 상태(qJoint=identity)면 vRel=[0 1 0]이 나온다.
%     3) 로컬 X(roll, mediolateral) 성분은 버리고 Y-Z 평면에서 atan2로 각도를
%        구한다: angle(t) = atan2(vRel_z(t), vRel_y(t)). PCA로 축을 추정하는
%        과정이 전혀 없다 - roll축이 곧 제외할 축이라는 게 고정 가정이기 때문.
%
%   computeAFOJointAngles(quaternion functional-hinge-twist 방식, PCA로 축을
%   찾음)와의 비교용. 반환 형식은 동일: AFOTime + left/right hip/knee/ankle
%   각도(deg) 테이블 + calibration.

if nargin < 2
    functionalTimeRange = [];
end

pairs = [0 1; 1 2; 2 3; 0 4; 4 5; 5 6];
jointNames = {'left_hip_angle', 'left_knee_angle', 'left_ankle_angle', ...
    'right_hip_angle', 'right_knee_angle', 'right_ankle_angle'};
limbAxisLocal = [0, 1, 0];  % pitch축 = limb 방향 가정

imuRaw = readAFOBagTopic(bagPath, '/afo_sensor/imu');
imuData.Time = imuRaw.Time;
imuData.Data = imuRaw.Data(:, 2:end);
imuStruct = get_IMU_fromBag(imuData);

zeroRaw = readAFOBagTopic(bagPath, '/afo_gui/kinematics_zero');
if numel(zeroRaw.Time) < 2
    error('computeAFOJointAnglesSagittal:missingZeroing', ...
        'Global and stand zeroing messages are both required: %s', bagPath);
end
zeroingTimeGlobal = zeroRaw.Time(1);
zeroingTimeStand = zeroRaw.Time(end);

[~, ~, qRelative, timeStruct] = cal_Angle_IMU(imuStruct, zeroingTimeGlobal, pairs);

afoTime = imuRaw.Time;
[~, idxZero] = min(abs(afoTime - zeroingTimeStand));

if isempty(functionalTimeRange)
    functionalTimeRange = [zeroingTimeStand, afoTime(end)];
else
    if numel(functionalTimeRange) ~= 2 || functionalTimeRange(1) >= functionalTimeRange(2)
        error('computeAFOJointAnglesSagittal:invalidFunctionalWindow', ...
            'functionalTimeRange must be [startTime endTime] with startTime < endTime.');
    end
    functionalTimeRange = reshape(functionalTimeRange, 1, 2);
end
% (이 방식은 축을 데이터로 추정하지 않으므로 functionalMask/functionalTimeRange는
%  계산에는 안 쓰이지만, computeAFOJointAngles와 동일한 인터페이스를 위해 받아서
%  calibration에 기록만 해 둔다.)

angleCols = zeros(numel(afoTime), numel(jointNames));
calibration = struct();
calibration.method = 'sagittal_fixed_axis_projection';
calibration.groundTime = zeroingTimeGlobal;
calibration.standTime = zeroingTimeStand;
calibration.functionalStartTime = functionalTimeRange(1);
calibration.functionalEndTime = functionalTimeRange(2);
calibration.joints = struct('name', {});

for k = 1:size(pairs, 1)
    nameA = sprintf('IMU_%d', pairs(k, 1));
    nameB = sprintf('IMU_%d', pairs(k, 2));

    qJoint = pairRelativeQuaternion(qRelative.(nameA), timeStruct.(nameA), ...
        qRelative.(nameB), timeStruct.(nameB));  % A 좌표계로 통일된 상대회전

    vRel = rotateVectorByQuat(qJoint, limbAxisLocal);  % A가 보는 B의 limb 방향
    angleRad = atan2(vRel(:, 3), vRel(:, 2));           % roll(X)축은 버리고 Y-Z 평면 각도
    angleDeg = rad2deg(angleRad);
    angleCols(:, k) = angleDeg - angleDeg(idxZero);      % stand neutral = 0 deg

    calibration.joints(k) = struct('name', jointNames{k});
end

angleTable = array2table([afoTime, angleCols], 'VariableNames', [{'AFOTime'}, jointNames]);
angleTable.Properties.UserData = calibration;
end

function qJoint = pairRelativeQuaternion(qA, tA, qB, tB)
idxB = interp1(tB, 1:numel(tB), tA, 'nearest', 'extrap');
qJoint = zeros(numel(tA), 4);
for i = 1:numel(tA)
    qJoint(i, :) = quatmultiply(quatinv(qA(i, :)), qB(idxB(i), :));
end
qJoint = quatnormalize(qJoint);
end

function vOut = rotateVectorByQuat(q, v)
% q: [N x 4] (w x y z), v: [1 x 3] 고정 벡터. sandwich product q*[0,v]*q^-1.
N = size(q, 1);
qv = [zeros(N, 1), repmat(v, N, 1)];
qInv = quatinv(q);
rotated = quatmultiply(quatmultiply(q, qv), qInv);
vOut = rotated(:, 2:4);
end
