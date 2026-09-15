function [ES, VaR] = PCAMeasures(alpha, numberOfPrincipalComponents, weights, portfolioValue, riskMeasureTimeIntervalInDays, returns)
% Gaussian parametric VaR and ES with PCA covariance reduction
%
% INPUT:
%   alpha  : confidence level (e.g. 0.99)
%   numberOfPrincipalComponents : number of PCA components to retain
%   weights: column vector of portfolio weights
%   portfolioValue: current portfolio value
%   riskMeasureTimeIntervalInDays: risk horizon in days
%   returns: matrix of daily returns
%
% OUTPUT:
%   ES  : Expected Shortfall
%   VaR : Value at Risk

% Basic checks
if size(weights, 2) > 1
    weights = weights';
end

[~, N] = size(returns);

if length(weights) ~= N
    error('Dimension mismatch: length(weights) must equal number of columns in returns.');
end

if numberOfPrincipalComponents < 1 || numberOfPrincipalComponents > N
    error('numberOfPrincipalComponents must be between 1 and N.');
end



% Mean vector and covariance matrix 
mu = mean(returns)';
Sigma = cov(returns);  

% Eigen-decomposition of covariance matrix
[V, D] = eig(Sigma);

% Sort eigenvalues descending
eigenvalues = diag(D);
[eigenvaluesSorted, idx] = sort(eigenvalues, 'descend');
V = V(:, idx);
D = diag(eigenvaluesSorted);

% Keep only the first k principal components
k = numberOfPrincipalComponents;
Vk = V(:, 1:k);
Dk = D(1:k, 1:k);

% PCA-approximated covariance matrix
Sigma_k = Vk * Dk * Vk';

% Portfolio mean and volatility
mu_p = weights' * mu;
sigma_p = sqrt(weights' * Sigma_k * weights);

% Gaussian VaR and ES
z_alpha = norminv(alpha);
pdf_z = normpdf(z_alpha);

VaR = portfolioValue * ( - mu_p * riskMeasureTimeIntervalInDays + sigma_p * sqrt(riskMeasureTimeIntervalInDays) * z_alpha );

ES = portfolioValue * ( -mu_p * riskMeasureTimeIntervalInDays + sigma_p * sqrt(riskMeasureTimeIntervalInDays) * (pdf_z / (1 - alpha)) );

end