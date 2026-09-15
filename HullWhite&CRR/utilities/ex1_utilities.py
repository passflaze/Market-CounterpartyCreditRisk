"""
Mathematical Engineering - Financial Engineering, FY 2025-2026
Risk Management - Exercise 1: Hedging a Swaption Portfolio
"""

from enum import Enum
import numpy as np
import pandas as pd
import datetime as dt
from utilities.date_functions import (
    year_frac_act_x,
    date_series,
    year_frac_30e_360,
    schedule_year_fraction,
)
from utilities.ex0_utilities import (
    get_discount_factor_by_zero_rates_linear_interp
)

from scipy.stats import norm

from typing import Union, List, Tuple


class SwapType(Enum):
    """
    Types of swaptions.
    """
    RECEIVER = "receiver"
    PAYER = "payer"


def swaption_price_calculator(
    S0: float,
    strike: float,
    ref_date: Union[dt.date, pd.Timestamp],
    expiry: Union[dt.date, pd.Timestamp],
    underlying_expiry: Union[dt.date, pd.Timestamp],
    sigma_black: float,
    freq: int,
    discount_factors: pd.Series,
    swaption_type: SwapType = SwapType.RECEIVER,
    compute_delta: bool = False,
) -> Union[float, Tuple[float, float]]:
    """
    Return the swaption price defined by the input parameters.

    Parameters:
        S0 (float): Forward swap rate.
        strike (float): Swaption strike price.
        ref_date (Union[dt.date, pd.Timestamp]): Value date.
        expiry (Union[dt.date, pd.Timestamp]): Swaption expiry date.
        underlying_expiry (Union[dt.date, pd.Timestamp]): Underlying forward starting swap expiry.
        sigma_black (float): Swaption implied volatility.
        freq (int): Number of times a year the fixed leg pays the coupon.
        discount_factors (pd.Series): Discount factors.
        swaption_type (SwapType): Swaption type, default to receiver.

    Returns:
        Union[float, Tuple[float, float]]: Swaption price (and possibly delta).
    """

    ttm = year_frac_act_x(ref_date, expiry, 365)
    d1 = (np.log(S0 / strike) + 0.5 * sigma_black ** 2 * ttm) / (sigma_black * np.sqrt(ttm))
    d2 = d1 - sigma_black * np.sqrt(ttm)

    fixed_leg_payment_dates = date_series(expiry, underlying_expiry, freq)
    bpv = basis_point_value(fixed_leg_payment_dates, discount_factors, expiry)  


    if swaption_type == SwapType.RECEIVER: # MODIFIED
        price = bpv * (strike * norm.cdf(-d2) - S0 * norm.cdf(-d1))
        delta = bpv * (norm.cdf(d1) - 1)
    elif swaption_type == SwapType.PAYER: # MODIFIED
        price = bpv * (S0 * norm.cdf(d1) - strike * norm.cdf(d2))
        delta = bpv * norm.cdf(d1)
    else:
        raise ValueError("Invalid swaption type.")

    if compute_delta:
        return price, delta
    else:
        return price


def irs_proxy_duration(
    ref_date: dt.date,
    swap_rate: float,
    fixed_leg_payment_dates: List[dt.date],
    discount_factors: pd.Series,
) -> float:
    """
    Given the specifics of an interest rate swap (IRS), return its rate sensitivity calculated as
    the duration of a fixed coupon bond.

    Parameters:
        ref_date (dt.date): Reference date.
        swap_rate (float): Swap rate.
        fixed_leg_payment_dates (List[dt.date]): Fixed leg payment dates.
        discount_factors (pd.Series): Discount factors.

    Returns:
        (float): Swap duration.
    """

    
    IBbond = 0.0
    numerator = 0.0

    t1 = ref_date

    for payment_date in fixed_leg_payment_dates:

        df = get_discount_factor_by_zero_rates_linear_interp(
                                                    ref_date,
                                                    payment_date, 
                                                    discount_factors.index, 
                                                    discount_factors.values
                                                    )

        if payment_date == fixed_leg_payment_dates[-1]:
            
            IBbond += ( 1 + swap_rate * year_frac_30e_360(t1, payment_date) ) * df # LAST PAYMENT, PRINCIPAL + COUPON

            numerator += ( 1 + swap_rate  * year_frac_30e_360(t1, payment_date) ) * year_frac_30e_360(ref_date, payment_date) * df 


        else: 
            
            IBbond += swap_rate * year_frac_30e_360(t1, payment_date) * df

            numerator += swap_rate * year_frac_30e_360(ref_date, payment_date) * year_frac_30e_360(t1, payment_date) * df 

        t1 = payment_date


    duration = numerator / IBbond

    return duration


def basis_point_value(
    fixed_leg_schedule: List[dt.datetime],
    discount_factors: pd.Series,
    settlement_date: dt.datetime | None = None,
) -> float:
    """
    Given a swap fixed leg payment dates and the discount factors, return the basis point value.

    Parameters:
        fixed_leg_schedule (List[dt.datetime]): Fixed leg payment dates.
        discount_factors (pd.Series): Discount factors.
        settlement_date (dt.datetime | None): Settlement date, default to None, i.e. to today.
            Needed in case of forward starting swaps.

    Returns:
        float: Basis point value.
    """


    t1 = settlement_date if settlement_date is not None else discount_factors.index[0]

    bpv = 0.0

    for payment_date in fixed_leg_schedule:

        df = get_discount_factor_by_zero_rates_linear_interp(
            discount_factors.index[0],
            payment_date,
            discount_factors.index,
            discount_factors.values
        )

        t2 = payment_date
        
        delta = year_frac_30e_360(t1, t2) 

        bpv += delta * df

        t1 = t2


    return bpv


def swap_par_rate(
    fixed_leg_schedule: List[dt.datetime],
    discount_factors: pd.Series,
    fwd_start_date: dt.datetime | None = None,
) -> float:
    """
    Given a fixed leg payment schedule and the discount factors, return the swap par rate. If a
    forward start date is provided, a forward swap rate is returned.

    Parameters:
        fixed_leg_schedule (List[dt.datetime]): Fixed leg payment dates.
        discount_factors (pd.Series): Discount factors.
        fwd_start_date (dt.datetime | None): Forward start date, default to None.

    Returns:
        float: Swap par rate.
    """


    if fwd_start_date is not None:
        discount_factor_t0 = get_discount_factor_by_zero_rates_linear_interp(
            discount_factors.index[0],
            fwd_start_date,
            discount_factors.index,
            discount_factors.values,
        )
    else:
        discount_factor_t0 = discount_factors.iloc[0]

    bpv = basis_point_value(fixed_leg_schedule, discount_factors, fwd_start_date) 

    discount_factor_tN = get_discount_factor_by_zero_rates_linear_interp(
        discount_factors.index[0],
        fixed_leg_schedule[-1],
        discount_factors.index,
        discount_factors.values,
    )
    float_leg = discount_factor_t0 - discount_factor_tN

    return float_leg / bpv


def swap_mtm(
    swap_rate: float,
    fixed_leg_schedule: List[dt.datetime],
    discount_factors: pd.Series,
    swap_type: SwapType = SwapType.PAYER,
) -> float:
    """
    Given a swap rate, a fixed leg payment schedule and the discount factors, return the swap
    mark-to-market.

    Parameters:
        swap_rate (float): Swap rate.
        fixed_leg_schedule (List[dt.datetime]): Fixed leg payment dates.
        discount_factors (pd.Series): Discount factors.
        swap_type (SwapType): Swap type, either 'payer' or 'receiver', default to 'payer'.

    Returns:
        float: Swap mark-to-market.
    """

    # Single curve framework, returns price and basis point value
    bpv = basis_point_value(fixed_leg_schedule, discount_factors) 
    P_term = get_discount_factor_by_zero_rates_linear_interp(
        discount_factors.index[0],
        fixed_leg_schedule[-1],
        discount_factors.index,
        discount_factors.values,
    )
    float_leg = 1.0 - P_term
    fixed_leg = swap_rate * bpv

    if swap_type == SwapType.PAYER:  # MODIFIED
        multiplier = 1
    elif swap_type == SwapType.RECEIVER: # MODIFIED
        multiplier = -1
    else:
        raise ValueError("Unknown swap type.")

    return multiplier * (float_leg - fixed_leg)


def shock_calculator(macro_buckets, df_depos, df_futures, df_swaps):
    """
    Generates a dictionary of Key Rate Shocks (tent functions) for a given set of macro buckets.
    
    Parameters:
    - macro_buckets: List of datetime objects representing the pivot points of the shocks.
    - df_depos, df_futures, df_swaps: DataFrames containing the market instruments for the curve.
    
    Returns:
    - shocks_dict: Dictionary {tenor_label: pd.Series} of basis point shocks.
    """
    
    # Consolidate all curve dates and initialize the results dictionary
    all_dates = pd.concat([
        pd.Series(df_depos.index),
        pd.Series(df_futures.index),
        pd.Series(df_swaps.index)
    ]).unique()
    dates = sorted(pd.to_datetime(all_dates))
    
    today = dates[0]
    # Sort buckets chronologically and calculate tenor labels (e.g., '10y')
    mb = sorted(pd.to_datetime(macro_buckets))
    n = len(mb)
    labels = [f"{round((d - today).days / 365.25)}y" for d in mb]
    
    shocks_dict = {label: pd.Series(0.0, index=dates) for label in labels}
    bp = 1e-4 # 1 basis point shock magnitude

    for i in range(n):
        current_label = labels[i]
        t_current = mb[i].toordinal()
        t_prev = mb[i-1].toordinal() if i > 0 else None
        t_next = mb[i+1].toordinal() if i < n-1 else None
        
        current_s = shocks_dict[current_label]
        
        for d in dates:
            d_ord = d.toordinal()
            
            # CASE 1: First bucket - constant 1bp before t_current, linear decay after
            if i == 0:
                if d_ord <= t_current:
                    current_s[d] = bp
                elif t_next and t_current < d_ord < t_next:
                    current_s[d] = bp * (t_next - d_ord) / (t_next - t_current)
            
            # CASE 2: Last bucket - linear growth before t_current, constant 1bp after
            elif i == n - 1:
                if t_prev and t_prev < d_ord < t_current:
                    current_s[d] = bp * (d_ord - t_prev) / (t_current - t_prev)
                elif d_ord >= t_current:
                    current_s[d] = bp
            
            # CASE 3: Intermediate buckets - triangular "tent" function
            else:
                # Linear growth from previous bucket to current
                if t_prev < d_ord <= t_current:
                    current_s[d] = bp * (d_ord - t_prev) / (t_current - t_prev)
                # Linear decay from current bucket to next
                elif t_next and t_current < d_ord < t_next:
                    current_s[d] = bp * (t_next - d_ord) / (t_next - t_current)
                    
    return shocks_dict