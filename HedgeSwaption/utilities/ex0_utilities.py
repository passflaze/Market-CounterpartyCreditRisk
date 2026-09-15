"""
Mathematical Engineering - Financial Engineering, FY 2025-2026
Risk Management - Exercise 0: Discount Factors Bootstrap
"""

import numpy as np
import pandas as pd
import datetime as dt
from utilities.date_functions import (
    business_date_offset,
    year_frac_act_x,
    year_frac_30e_360
)
from typing import Iterable, Union, List, Union, Tuple
import pickle
import matplotlib.pyplot as plt



def from_discount_factors_to_zero_rates(
    dates,
    discount_factors,
) :
    """
    Compute the zero rates from the discount factors.

    Parameters:
        dates (Union[List[float], pd.DatetimeIndex]): List of year fractions or dates.
        discount_factors (Iterable[float]): List of discount factors.

    Returns:
        List[float]: List of zero rates.
    """

    effDates, effDf = dates, discount_factors
    t0 = effDates[0]
    
    # Conditional preprocessing: if the input consists of Datetime objects, 
    # the function excludes the evaluation date (t0)
    if isinstance(effDates, pd.DatetimeIndex):                                          
        effDates = effDates[1:]
        effDf = discount_factors[1:]

    # Time Transformation: Calculate year fractions (Day Count Convention: ACT/365)
    # relative to the valuation date t0.
        delta = []
        for i in range(len(effDates)):
            delta.append(year_frac_act_x(t0, effDates[i], 365))
    else:
        delta = effDates
    # Mathematical Derivation
    zero_rates = -np.log(effDf) / delta   
    
    return zero_rates




def bootstrap(
    reference_date: dt.datetime,
    depo: pd.DataFrame,
    futures: pd.DataFrame,
    swaps: pd.DataFrame,
    depo_idx: list,
    fut_idx: list,
    shock: Union[float, pd.Series] = 0.0,
) -> pd.Series:
    """
    Bootstrap the discount factors from the given bid/ask market data. Deposit rates are used until
    the first future settlement date (included), futures rates are used until the 2y-swap settlement.

    Parameters:
        reference_date (dt.datetime): Reference date of the curve.
        depo (pd.DataFrame): Deposit rates.
        futures (pd.DataFrame): Futures rates.
        swaps (pd.DataFrame): Swaps rates.
        depo_idx (list): A pair of indices [start, end] specifying the subset of deposit
                         instruments from the 'depo' DataFrame to include in the bootstrap.
        fut_idx (list): A pair of indices [start, end] specifying the subset of futures
                        contracts to be utilized for the curve calibration.
        shock (Union[float, pd.Series]): Parallel shift to apply to the market rates, default to
            zero.

    Returns:
        pd.Series: Discount factors (index: dates, values: discount factors).
        pd.Series: Zero rates (index: dates excluding reference date, values: zero rates).
        pd.DatetimeIndex: Curve dates sequence, including the reference date.
    """
    if reference_date is None:
        raise ValueError("The 'reference_date' cannot be None. A valid start date is required for discounting.")
    
    if not isinstance(reference_date, (dt.datetime, pd.Timestamp)):
        raise TypeError(f"Invalid type for 'reference_date': {type(reference_date)}. Expected datetime or Timestamp.")
    
    # Initialize the lists of dates and discount factors
    termDates, discounts = [reference_date], [1.0]

    ### DEPOSITS ###
    if depo.empty:
        raise ValueError("The 'depo' DataFrame is empty. Short-end curve calibration is not possible.")
    
    # Instrument Selection Strategy:
    # Defining the subset of market instruments based on the provided index boundaries.
    # 'depo_idx' serves as a filter to ensure only liquid and non-overlapping 
    # instruments are utilized for calibration.
    if not depo_idx:
        # Default: utilizes the first 3 deposit instruments
        depo_idx = [0, 3]
        print("Warning: 'depo_idx' was empty. Defaulting to first 3 instruments.")
    first_depo = depo_idx[0]
    last_depo = depo_idx[1]
    depoDates = depo.index[first_depo:last_depo].to_list()    
    
    # Mid-Market Rate Derivation:
    # Calculating the arithmetic mean of Bid and Ask quotes.
    depoRates = depo.loc[depoDates].mean(axis=1).values 
    depoRates = depoRates +  ( shock if isinstance(shock, float) else shock[depoDates].values )

    # [Placeholder for sensitivity analysis / shock application]
    # EDIT depoRates = depoRates +  ( shock if isinstance(shock, float) else shock[depoDates].values )

    # Discounting:
    # Converting Linear Simple Rates (L) into Discount Factors (B).
    # The 'termDates' list is updated to maintain the chronological order of the curve.
    termDates += depoDates 
    t1 = reference_date
    delta = []
    
    # Day Count Convention (ACT/360):
    for t2 in termDates[1:]:
        delta.append(year_frac_act_x(t1, t2, 360))
    
    # Simple Compounding Transformation:
    # Formula: B(t0, ti) = 1 / (1 + L(t0, ti) * delta(t0, ti))
    discounts.extend(1 / (1 + (depoRates * delta)))

    
    ### FUTURES ###
    if futures.empty:
        raise ValueError("The 'futures' DataFrame is empty. Intermediate-segment calibration is not possible.")
    
    # Market Quote Normalization:
    # Selecting the relevant subset of contracts and calculating the Mid-Price.
    if not fut_idx:
        # Default: utilizes the first 7 futures contracts
        fut_idx = [0, 7]
        print("Warning: 'fut_idx' was empty. Defaulting to first 7 instruments.")

    first_fut = fut_idx[0]
    last_fut = fut_idx[1]
    futures_of_interest = futures.iloc[first_fut:last_fut, :].copy()
    mid_price = (futures_of_interest['BID'] + futures_of_interest['ASK']) / 2

    # Apply the shock
    if isinstance(shock, float):
        # Parallel shift
        futures_of_interest['Value'] = mid_price + shock
    else:
        # Variable Shock (Series): the perturbation is applied based on index alignment.
        futures_of_interest['Value'] = mid_price + shock[futures_of_interest.index].values

    # Forward Period Calculation:
    # Determining the accrual period between the Settle and Expiry dates 
    # for each contract, adhering to the ACT/360 convention.
    delta_futures = []
    for i in range(len(futures_of_interest)):
        t1 = futures_of_interest['Settle'].iloc[i]
        t2 = futures_of_interest['Expiry'].iloc[i]
        delta_futures.append(year_frac_act_x(t1, t2, 360))

    # Forward Discount Factor Derivation:
    # Converting the implied forward rate L(t0; ti-1, ti) into a 
    # Forward Discount Factor B(t0; ti-1, ti) for the specific contract period.
    futures_forward = 1 / (1 + delta_futures * futures_of_interest['Value'])

    # Sequential Bootstrapping and Gap Management:
    # The spot discount factor B(0, Ti) is calculated as B(0, Ti-1) * B(0; Ti-1, Ti).
    # This loop manages temporal gaps or overlaps between consecutive contracts 
    # via interpolation (flag=1) or extrapolation (flag=0).

    # Initialize the anchor with the last discount factor from the Deposits segment
    current_anchor_df = discounts[-1] 

    for i in range(len(futures_of_interest)):
        # 1. Compute the DF at the expiry of the current future starting from the current anchor
        df_expiry = current_anchor_df * futures_forward.iloc[i]
        
        # 2. Always store the expiry date and its corresponding DF
        discounts.append(df_expiry)
        termDates.append(futures_of_interest['Expiry'].iloc[i])

        # 3. Handle the gap/overlap for the NEXT contract
        if i < len(futures_of_interest) - 1:
            settle_next = futures_of_interest['Settle'].iloc[i+1]
            expiry_curr = futures_of_interest['Expiry'].iloc[i]
            
            if expiry_curr != settle_next:
                
                # Flag=1 if overlap (interp), Flag=0 if gap (extrap)
                current_anchor_df = get_discount_factor_by_zero_rates_linear_interp(
                    reference_date,
                    settle_next,
                    termDates,
                    discounts,
                )
            else:
                current_anchor_df = df_expiry
            
   
    #### SWAPS
    if swaps.empty:
        raise ValueError("The 'swaps' DataFrame is empty. Long-end curve calibration is not possible.")
    
    # Initialization of the Swap Segment:
    swapDates = swaps.index
    swap_old = swapDates[0]

    # Computing the first year fraction using the 30/360 convention, 
    # which is standard for fixed-leg swap coupons.
    swapYearFrac = [year_frac_30e_360(reference_date, swap_old)]

    # Bridge Interpolation:
    # Interpolating the first swap discount factor between the last known 
    # points of the Futures segment to ensure a seamless transition.
    interp_date = swap_old
    df = get_discount_factor_by_zero_rates_linear_interp(reference_date,
                                                        interp_date,
                                                        termDates,
                                                        discounts,
                                                        )

    swapDisc = [df] 

    # Calculate Mid-price for swaps
    swapRates = swaps.mean(axis=1).values + (
        shock if isinstance(shock, float) else shock[swaps.index].values
    ) 

    # Recursive Bootstrapping Loop:
    for idx in range(1, len(swapDates)):
        swapDate = swapDates[idx]
        rate = swapRates[idx]
        yf = year_frac_30e_360(swap_old, swapDate)

        # BPV (Basis Point Value) / PVBP (Present Value of a Basis Point):
        # Calculating the sum of year fractions weighted by discount factors 
        # for all previously determined coupon dates.
        bpv = sum(swapDisc[i] * swapYearFrac[i] for i in range(len(swapDisc)))

        # Solving for the Unknown Discount Factor:
        # Rearranging the swap pricing formula to solve for the terminal DF:
        # DF_n = (1 - FixedRate * BPV_known) / (1 + FixedRate * YearFrac_n)
        df = (1 - rate * bpv) / (1 + rate * yf)

        # Append newly calibrated data points to the term structure
        termDates.append(swapDate)
        swapDisc.append(df)
        swapYearFrac.append(yf)

        # Update the rolling reference date for the next interval
        swap_old = swapDate

    # Final Concatenation:
    # Merging the calibrated swap discount factors with the existing curve.
    discounts = discounts + swapDisc[1:]

    discount_factors = pd.Series(index=termDates, data=discounts)
    zero = from_discount_factors_to_zero_rates(discount_factors.index, discount_factors.values)
    zero_rates = pd.Series(index=termDates[1:], data=zero)
    termDates = pd.to_datetime(termDates)
    return discount_factors, zero_rates , termDates


def plot_curve(discount_factors, zero_rates):
    """
    Visualizes the term structure of interest rates by plotting Discount Factors 
    and Zero-Coupon Rates on a dual-axis chart.

    This function provides a graphical representation of the bootstrapping output, 
    allowing for a visual inspection of the curve's smoothness and monotonicity.

    Args:
        discount_factors (pd.Series): A series indexed by maturity dates containing 
                                      computed discount factors (P(0, T)).
        zero_rates (pd.Series): A series indexed by maturity dates containing 
                                the annualized zero-coupon rates (R(0, T)).
    """

    fig, ax1 = plt.subplots(figsize=(16, 5))
    
    # Plotting Discount Factors: Representing the present value of a unit payment
    ax1.plot(discount_factors.index, discount_factors.values, 'b-', label='Discount Factors')
    ax1.set_ylabel('Discount Factor Value', color='b')
    ax1.tick_params(axis='y', labelcolor='b')
    ax1.set_xlabel('Maturity Date')

    # Create a twin axes for Zero Rates to handle differing numerical scales
    # Zero rates are typically expressed in decimal or percentage form
    ax2 = ax1.twinx()
    ax2.plot(zero_rates.index, zero_rates.values, 'r-', label='Zero Rates')
    ax2.set_ylabel('Zero-Coupon Rate', color='r')
    ax2.tick_params(axis='y', labelcolor='r')

    # Add a unified legend for the dual-axis system
    fig.legend(loc="upper right", bbox_to_anchor=(1.0, 0.9), bbox_transform=ax1.transAxes)

    # Apply aesthetic adjustments and render the plot
    plt.title('Term Structure of Interest Rates: Discount Factors vs Zero Rates')
    plt.tight_layout()
    plt.show()


def get_discount_factor_by_zero_rates_linear_interp(
    reference_date,
    interp_date,
    dates,
    discount_factors,
) -> float:
    """
    Interpolates a discount factor at a specific target date using a linear interpolation 
    on the zero-coupon rates derived from a given set of discount factors.

    The function converts provided discount factors into continuously compounded zero rates, 
    identifies the relevant date interval for the target date, performs linear 
    interpolation on the zero rates, and finally converts the interpolated rate back 
    into a discount factor.

    Args:
        reference_date: The valuation or start date (t0).
        interp_date: The target date where the discount factor is required.
        dates: A list or index of market dates corresponding to the discount factors.
        discount_factors: Market discount factors for each date in 'dates'.

    Returns:
        float: The interpolated discount factor at interp_date.
    """
    
    # Validation: Ensure data alignment between dates and market instruments
    if len(dates) != len(discount_factors):
        raise ValueError("Dates and discount factors must have the same length.")
    if isinstance(dates, list):
        dates = pd.to_datetime(dates)
    # Step 1: Convert market discount factors into continuously compounded zero rates
    # Assumption: from_discount_factors_to_zero_rates is defined in your environment
    zero_rates = from_discount_factors_to_zero_rates(dates, discount_factors)
    zero_rates = np.insert(np.array(zero_rates), 0, 0.0)

    
    # Step 2: Identify the bounding interval (Equivalent to MATLAB's find(dates >= interp_date, 1))
    idx_after = -1
    for i, d in enumerate(dates):
        if d >= interp_date:
            idx_after = i
            break
    
    # Step 3: Perform Linear Interpolation on the Zero Rate (ZR)
    if idx_after == 0:
        # Target date is on or before the first available node
        interp_zr = zero_rates[0]
    elif idx_after == -1:
        # Target date is beyond the last node: perform extrapolation using the last two nodes
        idx_after = len(dates) - 1
        idx_before = idx_after - 1
        
        # Convert datetime objects to ordinal numbers for numpy's numerical interpolation
        x_coords = [dates[idx_before].toordinal(), dates[idx_after].toordinal()]
        y_coords = [zero_rates[idx_before], zero_rates[idx_after]]
        interp_zr = np.interp(interp_date.toordinal(), x_coords, y_coords)
    else:
        # Standard case: Target date lies between two nodes (idx_before and idx_after)
        idx_before = idx_after - 1
        
        # Define the X (dates as ordinals) and Y (zero rates) coordinates for interpolation
        x_coords = [dates[idx_before].toordinal(), dates[idx_after].toordinal()]
        y_coords = [zero_rates[idx_before], zero_rates[idx_after]]
        interp_zr = np.interp(interp_date.toordinal(), x_coords, y_coords)

    # Step 4: Re-convert the interpolated Zero Rate back to a Discount Factor
    # Use the specific year fraction convention (ACT/365) from reference_date to target
    delta = year_frac_act_x(reference_date, interp_date, 365)
    
    # Formula: DF = exp(-r * T)
    discount = np.exp(-interp_zr * delta)
    
    return float(discount)