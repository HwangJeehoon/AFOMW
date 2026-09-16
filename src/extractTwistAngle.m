function angle = extractTwistAngle(qDelta, axis)
% EXTRACTTWISTANGLE  지정한 hinge 축에 대한 quaternion twist angle을 반환한다.
%   qDelta : [N x 4] quaternion (w x y z), neutral stand 대비 상대 회전
%   axis   : [1 x 3] proximal 좌표계에서 정의된 단위 hinge 축
%   angle  : [N x 1] principal twist angle [-pi, pi] (rad)
%
% Euler roll을 직접 취하지 않고, 상대 회전을 hinge 축 twist와 나머지 swing으로
% 분해한다. 따라서 frontal/transverse 성분이 sagittal angle에 섞이는 것을 줄인다.
% 보행 관절각은 180도를 넘지 않는다는 전제에서 principal branch를 유지해,
% 비보행 구간의 quaternion branch가 수백 도로 누적되는 것을 막는다.

if size(qDelta, 2) ~= 4
    error('extractTwistAngle:invalidQuaternion', ...
        'qDelta must be an N-by-4 quaternion array [w x y z].');
end
if numel(axis) ~= 3 || ~all(isfinite(axis)) || norm(axis) == 0
    error('extractTwistAngle:invalidAxis', 'axis must be a finite nonzero 3-vector.');
end

axis = reshape(axis, 1, 3);
axis = axis / norm(axis);
q = quatnormalize(qDelta);

axisProjection = q(:, 2:4) * axis';
qTwist = [q(:, 1), axisProjection .* axis];
qTwistNorm = vecnorm(qTwist, 2, 2);
valid = qTwistNorm > eps;
qTwist(valid, :) = qTwist(valid, :) ./ qTwistNorm(valid);
qTwist(~valid, :) = repmat([1, 0, 0, 0], sum(~valid), 1);
qTwist(qTwist(:, 1) < 0, :) = -qTwist(qTwist(:, 1) < 0, :);  % principal branch [-pi, pi]

signedVectorPart = qTwist(:, 2:4) * axis';
angle = 2 * atan2(signedVectorPart, qTwist(:, 1));
end
