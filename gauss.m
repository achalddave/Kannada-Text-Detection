function [mat] = gauss(dimn, mu, sd)
    % [mat] = gauss(dimn, mu, sd)
    % dimn: [m, n]
    % mu  : [r, c] (1,1 is at top left)
    % sd  : [std_r, std_c]
    % Create an mxn matrix with a gaussian centered at mu with a standard
    % deviation of std.

    m = dimn(1);
    n = dimn(2);
    mu = [mu(1) - (m-1)/2, mu(2) - (n-1)/2];
    sig = [sd(1) 0 ; 0 sd(2)];

    r = (1:m) - (m+1)/2
    c = (1:n) - (n+1)/2

    [R, C] = meshgrid(r, c);
    mat = mvnpdf([R(:) C(:)], mu, sig);
    size(mat)
    mat = reshape(mat, m, n);
end
