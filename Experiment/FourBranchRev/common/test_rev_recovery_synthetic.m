function test_rev_recovery_synthetic
%TEST_REV_RECOVERY_SYNTHETIC 验证 3--9 状态复数与纯功率恢复。

rng(20260910); n=32; f=7; phaseDeg=0:45:360;
schedule=build_rev_state_schedule(phaseDeg,[0,90,180,270,45,135,225,315,360]);
h=(0.7+0.3*rand(n,f)).*exp(1j*2*pi*rand(n,f))+1.5;
total=sum(h,1); z=zeros(n,f,numel(phaseDeg));
for element=1:n
    b=total-h(element,:);
    for state=1:numel(phaseDeg)
        z(element,:,state)=b+h(element,:)*exp(1j*deg2rad(phaseDeg(state)));
    end
end
for slot=1:numel(schedule)
    index=schedule(slot).indices;
    [complexH,~,~]=recover_complex_harmonic_ls(z(:,:,index),deg2rad(phaseDeg(index)));
    [powerH,valid,~]=recover_power_rev_ls(abs(z(:,:,index)).^2, ...
        deg2rad(phaseDeg(index)),1e-12);
    complexAlignedError=aligned_error(complexH,h);
    expected=h./total;
    powerError=norm(powerH(:)-expected(:))/norm(expected(:));
    assert(complexAlignedError<1e-10 && all(valid,'all') && powerError<1e-10, ...
        '%d 状态恢复失败：complex %.3g, power %.3g。', ...
        schedule(slot).stateCount,complexAlignedError,powerError);
end
canonical=schedule([schedule.stateCount]==8);
[dftH,~,~]=recover_complex_dft(z(:,:,canonical.indices), ...
    deg2rad(phaseDeg(canonical.indices)));
assert(norm(dftH(:)-h(:))/norm(h(:))<1e-10,'8个唯一相位DFT恢复失败。');
fprintf('3--9 状态复谐波/纯功率恢复及8相位复数DFT合成测试全部通过。\n');
end

function value=aligned_error(a,b)
q=(a(:)'*b(:))/max(real(a(:)'*a(:)),realmin);
value=norm(q*a(:)-b(:))/norm(b(:));
end
