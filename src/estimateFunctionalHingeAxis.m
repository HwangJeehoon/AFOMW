function [axis, diagnostics] = estimateFunctionalHingeAxis(qDelta, functionalMask, refAxis, label)
% ESTIMATEFUNCTIONALHINGEAXIS  기준 자세 대비 상대 회전에서 주 hinge 축을 추정한다.
%   qDelta        : [N x 4] quaternion (w x y z), stand zero 대비 상대 회전
%   functionalMask: hinge 운동이 포함된 구간을 지정하는 [N x 1] logical mask
%   refAxis       : (선택) 부호를 고정할 기준 방향 [1 x 3]. 기본값 [1 0 0]으로,
%                   cal_Angle_IMU가 쓰던 "roll(1번째 컬럼) = 관절각" 관례와 동일한
%                   축이다(같은 quaternion 좌표계이므로 별도 회전 변환 없이 그대로
%                   내적 가능).
%   label         : (선택) 경고 메시지에 붙일 식별 문자열(예: 'SAH04/260728 P1 right_hip_angle').
%                   호출자(computeAFOJointAngles)가 어떤 트라이얼/조인트인지 표시한다.
%   axis          : 기준 proximal 좌표계의 단위 hinge 축 [1 x 3]
%
% 보행처럼 한 축 운동이 우세한 구간의 quaternion log(rotation vector)에 SVD를
% 적용한다. 정적/미세 회전은 제외하고, 첫 주성분을 hinge 축으로 사용한다.
% SVD가 주는 축의 부호는 임의이므로, 트라이얼마다 달라지지 않도록 고정 기준축
% (refAxis)과의 내적으로 부호를 정한다. 예전처럼 "운동 범위가 큰 쪽을 +로" 하는
% percentile 비교는 배굴/저굴처럼 ROM이 대칭적인 관절에서 노이즈만으로 부호가
% 뒤집힐 수 있어(트라이얼 간 재현성 없음) 고정 기준축 방식으로 대체한다.

if nargin < 3 || isempty(refAxis)
    refAxis = [1, 0, 0];
end
if nargin < 4 || isempty(label)
    label = '';
end
if numel(refAxis) ~= 3 || ~all(isfinite(refAxis)) || norm(refAxis) == 0
    error('estimateFunctionalHingeAxis:invalidRefAxis', ...
        'refAxis must be a finite nonzero 3-vector.');
end
refAxis = reshape(refAxis, 1, 3) / norm(refAxis);

if size(qDelta, 2) ~= 4
    error('estimateFunctionalHingeAxis:invalidQuaternion', ...
        'qDelta must be an N-by-4 quaternion array [w x y z].');
end
if numel(functionalMask) ~= size(qDelta, 1)
    error('estimateFunctionalHingeAxis:invalidMask', ...
        'functionalMask length must match qDelta rows.');
end

functionalMask = logical(functionalMask(:));
q = quatnormalize(qDelta);
q(q(:, 1) < 0, :) = -q(q(:, 1) < 0, :);  % principal rotation (0~pi)

v = q(:, 2:4);
vNorm = vecnorm(v, 2, 2);
angle = 2 * atan2(vNorm, q(:, 1));
rotVec = zeros(size(v));
nonZero = vNorm > eps;
rotVec(nonZero, :) = v(nonZero, :) ./ vNorm(nonZero) .* angle(nonZero);

isUsable = functionalMask & all(isfinite(rotVec), 2);
if sum(isUsable) < 50
    error('estimateFunctionalHingeAxis:insufficientSamples', ...
        'At least 50 finite samples are required for functional calibration.');
end

mag = vecnorm(rotVec, 2, 2);
motionThreshold = max(deg2rad(2), prctile(mag(isUsable), 50));
selected = isUsable & mag >= motionThreshold;
if sum(selected) < 50
    selected = isUsable;
end

centered = rotVec(selected, :) - mean(rotVec(selected, :), 1);
[~, singularValues, vectors] = svd(centered, 'econ');
axis = vectors(:, 1)';
axis = axis / norm(axis);

% 고정 기준축(refAxis)과 내적이 양수가 되도록 부호를 정한다.
refAlignment = dot(axis, refAxis);
if refAlignment < 0
    axis = -axis;
    refAlignment = -refAlignment;
end
if abs(refAlignment) < 0.3
    if isempty(label)
        labelSuffix = '';
    else
        labelSuffix = sprintf(' [%s]', label);
    end
    warning('estimateFunctionalHingeAxis:lowRefAlignment', ...
        'hinge axis가 기준축(refAxis)과 거의 수직입니다(|dot|=%.2f)%s - 부호 판정이 불안정할 수 있습니다.', ...
        abs(refAlignment), labelSuffix);
end
projection = rotVec(isUsable, :) * axis';

singularVals = diag(singularValues);
diagnostics = struct();
diagnostics.sampleCount = sum(isUsable);
diagnostics.selectedSampleCount = sum(selected);
diagnostics.explainedVariance = singularVals(1)^2 / sum(singularVals.^2);
diagnostics.refAlignment = refAlignment;
diagnostics.p05Deg = rad2deg(prctile(projection, 5));
diagnostics.p95Deg = rad2deg(prctile(projection, 95));
end
