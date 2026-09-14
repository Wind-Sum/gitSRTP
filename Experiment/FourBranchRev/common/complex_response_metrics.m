function metrics=complex_response_metrics(reference,candidate,frequencyIndices,minElements)
%COMPLEX_RESPONSE_METRICS 公共复标量对齐后的宽带阵元响应一致性。

coherence=[]; phaseRmse=[]; complexNmse=[]; magnitudeNrmse=[]; magnitudeCorrelation=[];
for frequencyIndex=frequencyIndices(:).'
    a=reference(:,frequencyIndex); b=candidate(:,frequencyIndex);
    valid=isfinite(a)&isfinite(b);
    if nnz(valid)<minElements, continue; end
    a=a(valid); b=b(valid);
    q=(a'*b)/max(real(a'*a),realmin);
    fitted=q*a;
    coherence(end+1)=abs(a'*b)/max(norm(a)*norm(b),realmin); %#ok<AGROW>
    phaseRmse(end+1)=sqrt(mean(angle(b./fitted).^2))*180/pi; %#ok<AGROW>
    complexNmse(end+1)=10*log10(sum(abs(b-fitted).^2)/max(sum(abs(b).^2),realmin)); %#ok<AGROW>
    magnitudeNrmse(end+1)=norm(abs(b)-abs(fitted))/max(norm(abs(b)),realmin); %#ok<AGROW>
    c=corrcoef(20*log10(max(abs(a),realmin)),20*log10(max(abs(b),realmin)));
    magnitudeCorrelation(end+1)=c(1,2); %#ok<AGROW>
end
metrics.medianCoherence=median(coherence,'omitnan');
metrics.medianPhaseRmseDeg=median(phaseRmse,'omitnan');
metrics.medianComplexNmseDb=median(complexNmse,'omitnan');
metrics.medianMagnitudeNrmse=median(magnitudeNrmse,'omitnan');
metrics.medianMagnitudeCorrelation=median(magnitudeCorrelation,'omitnan');
metrics.frequencyCount=numel(coherence);
end
