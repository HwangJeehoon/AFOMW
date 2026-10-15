function [angleTable, calibration] = computeAFOJointAnglesPairSagittal(bagPath, functionalTimeRange)
% COMPUTEAFOJOINTANGLESPAIRSAGITTAL  [LEGACY] 센서 pair의 상대 quaternion을 구한 뒤 sagittal
% 평면에 투영하는 방식. 현재 main(src/computeAFOJointAngles.m)은 센서별 x축 둘레
% 회전각의 차이를 쓴다(센서 간 holder 정렬 오차의 영향을 받지 않기 때문).
% 비교/회귀 검증용으로만 보존한다.
% 원래 설명: AFO .bag 하나에서 좌우 고관절/무릎/발목 sagittal 상대각
% (트라이얼 전체, IMU 원 샘플레이트)을 계산한다. IMU 로컬 pitch축이 그 segment의
% limb 장축과 일치한다는 가정 아래, roll축과 normal한 평면(=sagittal plane)에
% 투영한 각도를 구한다(PCA로 hinge축을 추정하던 예전 방식은
% src/legacy/computeAFOJointAnglesHingeTwist.m로 이동).
%
%   가정(고정, 데이터로 추정하지 않음):
%     - 각 IMU 로컬 Y축("pitch"가 도는 축) = 그 segment의 뼈 장축(limb direction)
%     - 각 IMU 로컬 X축("roll"이 도는 축)  = mediolateral(내외측) 방향
%   두 가정이 맞다면, local Y-Z 평면(=roll축과 normal한 평면)이 곧 sagittal
%   plane이 되고, 그 평면에 투영한 각도가 sagittal(굴곡-신전) 각도가 된다.
%
%   계산 순서:
%     1) global zeroing(zeroingTimeGlobal) 기준으로 각 IMU의 상대자세를 구한다
%        (cal_Angle_IMU). qJoint(t) = quatinv(qA(t)) ⊗ qB(t)로 A/B 각자의
%        (서로 무관하게 임의로 정해지는) global-zero 기준을 상쇄해 "A 좌표계에서
%        본 B의 상대회전"이라는 하나의 일관된 좌표계로 만든다(초안에서는 이 단계
%        없이 vA, vB를 각자 좌표계에서 따로 구해 바로 cross해서 좌표계가 안 맞는
%        채로 계산되는 버그가 있었다 - 수정됨).
%     2) vRel(t) = qJoint(t)로 로컬 Y축[0 1 0]을 회전 → A가 보는 B의 limb 방향.
%        정지 상태(qJoint=identity)면 vRel=[0 1 0]이 나온다.
%     3) 로컬 X(roll, mediolateral) 성분은 버리고 Y-Z 평면(=sagittal plane)에서
%        A 자신의 방향[0 1 0]과 vRel(t) 사이의 부호 있는 각도를 구한다:
%        raw(t) = atan2(vRel_z(t), vRel_y(t)) (-180~180도, abs 없음 - 절대값을
%        쓰면 실제로 0도를 지나가는 관절(특히 hip)에서 신호가 접혀서(fold)
%        상관관계가 깨지는 문제가 있었다).
%     4) zeroingTimeStand 시점 값을 offset으로 빼서 stand 자세 기준 변화량으로
%        만든 뒤, 관절별 지정 부호(signMultiplier)를 곱해 최종 각도를 만든다:
%          hip  : ×-1  (허벅지가 torso와 가까워지는 flexion이 양수가 되도록)
%          knee : ×+1  (무릎이 굽혀지는 flexion이 양수 - raw 그대로 이미 맞음)
%          ankle: ×+1  (발목이 펴지는 plantarflexion이 양수 - raw 그대로 이미 맞음)
%        이 부호는 SAH01/260706, SAH03/260623(둘 다 문제 없다고 확인된 트라이얼)
%        에서, 보행 중 각 이벤트의 타이밍이 명확한 지점(hip: heel strike=최대
%        flexion, knee: toe-off 직후 swing=최대 flexion, ankle: toe-off 부근
%        push-off=최대 plantarflexion)의 실측값 부호로 직접 확인했다. ankle은
%        다른 트라이얼에서 신호가 약해 hip/knee보다 확신도가 낮다.
%
%   반환 테이블 컬럼: AFOTime(절대 epoch초), left_hip_angle, left_knee_angle,
%   left_ankle_angle, right_hip_angle, right_knee_angle, right_ankle_angle (모두 deg)

if nargin < 2
    functionalTimeRange = [];
end

pairs = [0 1; 1 2; 2 3; 0 4; 4 5; 5 6];
jointNames = {'left_hip_angle', 'left_knee_angle', 'left_ankle_angle', ...
    'right_hip_angle', 'right_knee_angle', 'right_ankle_angle'};
% flexion(hip/knee)·plantarflexion(ankle)이 양수가 되도록 실측으로 정한 부호
signMultiplier = [-1, 1, 1, -1, 1, 1];
limbAxisLocal = [0, 1, 0];  % pitch축 = limb 방향 가정

imuRaw = readAFOBagTopic(bagPath, '/afo_sensor/imu');
imuData.Time = imuRaw.Time;
imuData.Data = imuRaw.Data(:, 2:end);
imuStruct = get_IMU_fromBag(imuData);

zeroRaw = readAFOBagTopic(bagPath, '/afo_gui/kinematics_zero');
if numel(zeroRaw.Time) < 2
    error('computeAFOJointAnglesPairSagittal:missingZeroing', ...
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
        error('computeAFOJointAnglesPairSagittal:invalidFunctionalWindow', ...
            'functionalTimeRange must be [startTime endTime] with startTime < endTime.');
    end
    functionalTimeRange = reshape(functionalTimeRange, 1, 2);
end
% (이 방식은 축을 데이터로 추정하지 않으므로 functionalMask/functionalTimeRange는
%  계산에는 안 쓰이지만, 예전 hinge-twist 방식과 동일한 인터페이스를 유지하기
%  위해 받아서 calibration에 기록만 해 둔다.)

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
    rawDeg = rad2deg(atan2(vRel(:, 3), vRel(:, 2)));    % roll(X) 버리고 Y-Z 평면, 부호 유지
    relDeg = rawDeg - rawDeg(idxZero);                   % stand 시점 값을 offset으로 보정
    angleCols(:, k) = signMultiplier(k) * relDeg;         % flexion/plantarflexion 양수로 부호 고정

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
