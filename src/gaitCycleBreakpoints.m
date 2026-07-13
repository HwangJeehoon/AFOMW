function pct = gaitCycleBreakpoints(subject)
% GAITCYCLEBREAKPOINTS  subject별 [start mid end] gait cycle % 경계.
%   start = low 시작 tick, mid = high 시작 tick, end = 다음 step의 start(=100%p 뒤)

switch upper(subject)
    case 'SAH01'
        pct = [0, 70, 100];
    case 'SAH03'
        pct = [-10, 60, 90];
    otherwise
        error('gaitCycleBreakpoints:unknownSubject', ...
            'No gait cycle breakpoints defined for subject %s', subject);
end
end
