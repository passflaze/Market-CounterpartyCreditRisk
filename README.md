# Quantitative Risk & Exposure Management Engine

A quantitative framework for portfolio risk measurement, interest rate immunization, and counterparty credit risk profiling.

## Overview

* **Market Risk Analytics:** Computed parametric, historical, and EWMA-weighted Value at Risk (VaR) and Expected Shortfall (ES) on equity portfolios. Leveraged PCA covariance dimensionality reduction and benchmarked Delta-Normal/Delta-Gamma analytical approximations against full Monte Carlo revaluation engines for nonlinear derivatives portfolios.
* **Interest Rate Risk & Immunization:** Evaluated interest rate sensitivities on interest rate swaps and swaption portfolios using full-revaluation numerical DV01. Designed and backtested multi-instrument coarse-grained bucket Delta immunization frameworks to hedge against non-parallel yield curve shifts, steepening, and flattening scenarios.
* **Counterparty Credit Risk (CCR) & XVA:** Simulated stochastic forward MtM paths under single-curve Hull-White 1-factor dynamics to profile Expected Exposure (EE), Expected Positive Exposure (EPE), and Potential Future Exposure (PFE). Quantified unilateral Credit Valuation Adjustment (CVA) integrating netting sets, break clauses, and daily CSA variation margining with collateral thresholds.
