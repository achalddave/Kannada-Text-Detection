function [ OUT ] = gauss2d(h, w, cx, cy, sigma)
    X = repmat((-(cx-1):w-cx),[h,1]);
    Y = repmat((cy-1:-1:cy-h)',[1,w]);
    OUT = exp(-1*(X.^2/(2*sigma^2) + Y.^2/(2*sigma^2)));
end