import math

def price_to_tick(price):
    # Calculate tick from price
    log_base = math.log(1.0001)
    tick = math.log(price) / log_base
    return int(round(tick))


# Example: price = 0.01 (ETH per token)
price = 0.01
tick = price_to_tick(price)
tick

# mcap
billion = 1000000000
billion * price
