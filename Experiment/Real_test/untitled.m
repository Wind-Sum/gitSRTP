% H = result.HChannel(30,:);
H = result.HElement(30,:);
% H = result.HRevPower(20,:);
% H3 = result.HRevComplex(9,:);


figure
plot(db(H))
h = ifft(H,8192);
figure
plot(db(h));
%%
figure
plot(db(H3./H2))

figure
plot(rad2deg(angle(H3./H2)))


